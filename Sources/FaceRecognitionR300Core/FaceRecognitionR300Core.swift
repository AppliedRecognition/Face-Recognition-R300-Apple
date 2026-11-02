import Foundation
import UIKit
import Accelerate
import VerIDCommonTypes
import FaceAlignmentCore

/// An abstract base class that implements common logic for R300-series face recognition.
///
/// This class conforms to the `FaceRecognition` protocol and provides:
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
/// - Aligns the faces it is given rather than re-detecting them, which matches the Android
///   implementation (`EdgeFaceOnnxRecognition.createFaceRecognitionTemplates`) and removes two
///   things: a second face detector, and a failure mode where a re-detection miss became a
///   template extraction failure.
/// - Provides a default threshold of 0.5 for similarity checks, which can be overridden by subclasses.
///
/// ## Typealiases:
/// - `Version`: ``R300``, the face template version identifier.
/// - `TemplateData`: `[Float]`, the raw embedding vector type.
///
/// ## Initialization:
/// - ``init()`` traps if instantiated directly, as this is an abstract class. Use a concrete subclass.
///
/// ## Public API:
/// - ``createFaceRecognitionTemplates(from:in:)``
///   - Aligns the detected faces, generates embeddings via the subclass implementation,
///     and normalizes the resulting templates.
/// - ``compareFaceRecognitionTemplates(_:to:)``
///   - Compares multiple templates to a reference template using cosine similarity (clamped to [0, 1]).
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
    /// Default similarity threshold for R300 verification and identification.
    ///
    /// 0.5 matches the Android R300 implementation (`EdgeFaceOnnxRecognition.defaultThreshold`)
    /// and the product's intended cut-off. It was 0.6, which no other platform used. On the parity
    /// fixture set 0.5 separates every same-subject pair from every cross-subject pair on both CPU
    /// and GPU compute: the closest same-subject pair scores 0.5912 and the highest cross-subject
    /// pair stays well below 0.12.
    public var defaultThreshold: Float = 0.5
    public var faceAlignmentConfiguration: FaceAlignmentConfiguration = FaceAlignmentConfiguration()
    
    /// Initializes a new instance of the R300-series face recognition core.
    ///
    /// - Important: This class is abstract. Attempting to initialize ``FaceRecognitionR300Core``
    ///   directly will cause a runtime crash via `fatalError`. You must subclass
    ///   ``FaceRecognitionR300Core`` and initialize the subclass instead.
    ///
    /// - Note: This initialiser no longer loads anything, so it has nothing to throw or await.
    ///   It keeps the `async throws` signature because subclasses override it and Swift does not
    ///   allow an override to add `throws` or `async`. Removing them would force
    ///   ``FaceRecognitionR300Cloud``'s convenience initialiser, which throws for Info.plist
    ///   configuration errors, to stop throwing.
    public init() async throws {
        guard type(of: self) != FaceRecognitionR300Core.self else {
            fatalError("Abstract base class called its initialiser")
        }
    }
    
    /// Creates normalized face recognition templates for R300 embeddings from detected faces in an image.
    ///
    /// This method performs the R300 template pipeline:
    /// 1. Aligns each provided face using ``FaceAlignment`` to produce a standardized, cropped face image.
    /// 2. Delegates to the subclass implementation of ``createFaceRecognitionTemplatesFromAlignedFaceImages(_:)``
    ///    to generate raw embedding vectors.
    /// 3. Normalizes each resulting template to unit length, enabling cosine similarity comparisons.
    ///
    /// The faces are used as given. They are not re-detected, which is what the Android
    /// implementation does and what keeps the alignment landmarks consistent with whichever
    /// detector supplied the face.
    ///
    /// - Parameters:
    ///   - faces: Face detections associated with the input image.
    ///   - image: The source image that contains the detected faces.
    /// - Returns: An array of normalized face templates suitable for cosine similarity comparison.
    /// - Throws: Any error thrown by alignment, or by the subclass implementation that generates embeddings.
    /// - Note:
    ///   - The returned templates are normalized to unit length using `Accelerate` for efficient vector math.
    ///   - Subclasses must implement ``createFaceRecognitionTemplatesFromAlignedFaceImages(_:)`` to provide embeddings.
    /// - SeeAlso:
    ///   - ``createFaceRecognitionTemplatesFromAlignedFaceImages(_:)``
    ///   - ``compareFaceRecognitionTemplates(_:to:)``
    public func createFaceRecognitionTemplates(from faces: [VerIDCommonTypes.Face], in image: VerIDCommonTypes.Image) async throws -> [VerIDCommonTypes.FaceTemplate<R300, [Float]>] {
        let alignedFaces = try faces.map { face in
            try FaceAlignment.alignFace(face, image: image, scale: self.faceAlignmentConfiguration.scale, verticalOffset: self.faceAlignmentConfiguration.verticalOffset)
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
}

public struct R300: FaceTemplateVersion {
    public static let id: Int = 300
}
