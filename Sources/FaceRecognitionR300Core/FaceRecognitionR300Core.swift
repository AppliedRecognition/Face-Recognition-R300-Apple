import Foundation
import UIKit
import Accelerate
import VerIDCommonTypes
import FaceDetectionRetinaFaceOrt
@_spi(Testing) import FaceRecognitionArcFaceCore

/// An abstract base class that implements common logic for R300-series face recognition.
/// 
/// This class conforms to the `FaceRecognition` protocol and provides:
/// - Face detection refinement via RetinaFace (ONNX Runtime).
/// - Face alignment using ``FaceAlignment``.
/// - Template normalization and cosine similarity comparison utilities.
/// - A default verification threshold suitable for R300 embeddings.
/// 
/// Subclasses must implement ``createFaceRecognitionTemplatesFromAlignedFaceImages(_:)`` to produce raw
/// embedding vectors from aligned `UIImage` inputs.
///
/// ## Key features:
/// - Uses `Accelerate` for efficient vector math (dot product, normalization).
/// - Normalizes template vectors to unit length to enable cosine similarity comparison.
/// - Refines provided faces by re-detecting faces in the image and matching them by eye-center proximity.
/// - Provides a default threshold of 0.6 for similarity checks, which can be overridden by subclasses.
///
/// ## Typealiases:
/// - `Version`: ``R300``, the face template version identifier.
/// - `TemplateData`: `[Float]`, the raw embedding vector type.
///
/// ## Initialization:
/// - ``init()`` throws if instantiated directly, as this is an abstract class. Use a concrete subclass.
///
/// ## Public API:
/// - ``createFaceRecognitionTemplates(from:in:)``
///   - Refines detected faces, aligns them, generates embeddings via subclass implementation,
///     and normalizes the resulting templates.
/// - ``compareFaceRecognitionTemplates(_:to:)``
///   - Compares multiple templates to a reference template using cosine similarity (clamped to [0, 1]).
///
/// ## Errors:
/// - Throws ``FaceRecognitionError.faceDetectionFailure`` when the number of refined faces does not match the input count.
///
/// ## Threading:
/// - Public async methods leverage Swift Concurrency and can be awaited from asynchronous contexts.
///
/// ## Usage:
/// - Subclass ``FaceRecognitionR300Core`` and implement ``createFaceRecognitionTemplatesFromAlignedFaceImages(_:)``
///   to integrate a specific embedding model.
/// - Call ``createFaceRecognitionTemplates(from:in:)`` with detected faces and the source image to obtain normalized templates.
/// - Use ``compareFaceRecognitionTemplates(_:to:)`` to compute similarity scores for verification or identification workflows.
open class FaceRecognitionR300Core: FaceRecognition {
    
    public typealias Version = R300
    public typealias TemplateData = [Float]
    public var defaultThreshold: Float = 0.6
    
    let faceDetection: FaceDetectionRetinaFaceOrt
    
    /// Initializes a new instance of the R300-series face recognition core.
    ///
    /// - Important: This class is abstract. Attempting to initialize ``FaceRecognitionR300Core``
    ///   directly will cause a runtime crash via `fatalError`. You must subclass
    ///   ``FaceRecognitionR300Core`` and initialize the subclass instead.
    ///
    /// - Throws: Rethrows any error encountered while creating the internal face detector
    ///   (`FaceDetectionRetinaFaceOrt`). This can fail if the ONNX Runtime model or resources
    ///   are unavailable or invalid.
    ///
    /// - Postcondition: On success, the instance is configured with a RetinaFace-based detector
    ///   used for refining input face detections prior to alignment and template extraction.
    ///
    /// - SeeAlso: ``FaceRecognitionR300Core/createFaceRecognitionTemplates(from:in:)``,
    ///   ``FaceRecognitionR300Core/refineFaces(_:inImage:)``,
    ///   ``FaceRecognitionR300Core/createFaceRecognitionTemplatesFromAlignedFaceImages(_:)``.
    public init() throws {
        guard type(of: self) != FaceRecognitionR300Core.self else {
            fatalError("Abstract base class called its initialiser")
        }
        self.faceDetection = try FaceDetectionRetinaFaceOrt()
    }
    
    /// Creates normalized face recognition templates for R300 embeddings from detected faces in an image.
    ///
    /// This method performs the full R300 template pipeline:
    /// 1. Refines the provided face detections by re-detecting faces in the image using RetinaFace (ONNX Runtime)
    ///    and matching them to the originals by eye-center proximity.
    /// 2. Aligns each refined face using ``FaceAlignment`` to produce standardized, cropped face images.
    /// 3. Delegates to the subclass implementation of ``createFaceRecognitionTemplatesFromAlignedFaceImages(_:)``
    ///    to generate raw embedding vectors.
    /// 4. Normalizes each resulting template to unit length, enabling cosine similarity comparisons.
    ///
    /// - Parameters:
    ///   - faces: An array of initial face detections associated with the input image. These are refined internally
    ///            by re-detection and matching before alignment and embedding extraction.
    ///   - image: The source image that contains the detected faces.
    /// - Returns: An array of normalized face templates suitable for cosine similarity comparison.
    /// - Throws:
    ///   - ``FaceRecognitionError.faceDetectionFailure`` if the number of refined faces does not match the input count,
    ///     which can occur if re-detection fails or yields mismatched results.
    ///   - Any error thrown by the internal face detector or by the subclass implementation that generates embeddings.
    /// - Note:
    ///   - The returned templates are normalized to unit length using `Accelerate` for efficient vector math.
    ///   - Subclasses must implement ``createFaceRecognitionTemplatesFromAlignedFaceImages(_:)`` to provide embeddings.
    /// - SeeAlso:
    ///   - ``refineFaces(_:inImage:)``
    ///   - ``createFaceRecognitionTemplatesFromAlignedFaceImages(_:)``
    ///   - ``compareFaceRecognitionTemplates(_:to:)``
    public func createFaceRecognitionTemplates(from faces: [VerIDCommonTypes.Face], in image: VerIDCommonTypes.Image) async throws -> [VerIDCommonTypes.FaceTemplate<R300, [Float]>] {
        let refinedFaces = try await self.refineFaces(faces, inImage: image)
        let alignedFaces = try refinedFaces.map { face in
            try FaceAlignment.alignFace(face, image: image)
        }
        let templates = try await self.createFaceRecognitionTemplatesFromAlignedFaceImages(alignedFaces)
        return templates.map { template in
            var data = template.data
            self.normalize(&data)
            return FaceTemplate(data: data)
        }
    }
    
    /// Compares one or more R300 face recognition templates against a reference template using cosine similarity.
    /// 
    /// This method assumes all templates were previously L2-normalized (unit length). When vectors are normalized,
    /// the dot product is equivalent to cosine similarity. The resulting similarity scores are clamped to the
    /// [0.0, 1.0] range for stability.
    /// 
    /// - Parameters:
    ///   - faceRecognitionTemplates: An array of normalized templates to compare against the reference template.
    ///   - template: The normalized reference template to which all other templates are compared.
    /// - Returns: An array of similarity scores (one per input template), where:
    ///   - 1.0 indicates identical direction (maximum similarity),
    ///   - 0.0 indicates orthogonality (no similarity).
    /// - Important: For meaningful and consistent results, ensure all templates (including the reference) are
    ///   L2-normalized prior to comparison. Use the normalization provided by this class’s template creation pipeline.
    /// - SeeAlso: ``createFaceRecognitionTemplates(from:in:)`` for producing normalized templates suitable for comparison.
    public func compareFaceRecognitionTemplates(_ faceRecognitionTemplates: [VerIDCommonTypes.FaceTemplate<R300, [Float]>], to template: VerIDCommonTypes.FaceTemplate<R300, [Float]>) async throws -> [Float] {
        let n = vDSP_Length(template.data.count)
        return faceRecognitionTemplates.map { t in
            var dotProduct: Float = 0.0
            vDSP_dotpr(template.data, 1, t.data, 1, &dotProduct, n)
            return min(max(dotProduct, 0.0), 1.0)
        }
    }
    
    @_spi(Testing) open func createFaceRecognitionTemplatesFromAlignedFaceImages(_ images: [UIImage]) async throws -> [VerIDCommonTypes.FaceTemplate<R300, [Float]>] {
        fatalError("Method not implemented")
    }
    
    private func norm(_ template: [Float]) -> Float {
        let n = vDSP_Length(template.count)
        var norm: Float = 0.0
        vDSP_svesq(template, 1, &norm, n)
        return sqrt(norm)
    }
    
    @_spi(Testing) public func normalize(_ x: inout [Float]) {
        let n = norm(x)
        if n > 0 {
            let inv = 1/n
            vDSP_vsmul(x, 1, [inv], &x, 1, vDSP_Length(x.count))
        }
    }
    
    @_spi(Testing) public func refineFaces(_ faces: [Face], inImage image: Image) async throws -> [Face] {
        let detectedFaces = try await self.faceDetection.detectFacesInImage(image, limit: faces.count)
        guard detectedFaces.count == faces.count else {
            throw FaceRecognitionError.faceDetectionFailure
        }
        let refinedFaces: [Face] = faces.compactMap { originalFace in
            return detectedFaces.min { a, b in
                return a.eyeCentre.distance(to: originalFace.eyeCentre) < b.eyeCentre.distance(to: originalFace.eyeCentre)
            }
        }
        guard refinedFaces.count == faces.count else {
            throw FaceRecognitionError.faceDetectionFailure
        }
        return refinedFaces
    }
}

public struct R300: FaceTemplateVersion {
    public static let id: Int = 300
}


fileprivate extension CGPoint {
    
    func distance(to other: CGPoint) -> CGFloat {
        return hypot(other.y - self.y, other.x - self.x)
    }
}

fileprivate extension Face {
    
    var eyeCentre: CGPoint {
        CGPoint(x: (self.rightEye.x + self.leftEye.x) * 0.5, y: (self.rightEye.y + self.leftEye.y) * 0.5)
    }
}
