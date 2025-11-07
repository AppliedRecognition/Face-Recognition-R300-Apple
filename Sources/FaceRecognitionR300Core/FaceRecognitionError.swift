//
//  FaceRecognitionError.swift
//  FaceRecognitionR300
//
//  Created by Jakub Dolejs on 28/10/2025.
//

import Foundation

/// An error type representing failures that can occur during face recognition operations.
///
/// `FaceRecognitionError` conforms to `LocalizedError` and provides user-facing
/// descriptions for each failure case via `errorDescription`.
///
/// ## Cases:
/// - ``faceTemplateExtractionFailed``: Indicates that extracting a face template from the provided
///   image or data source did not succeed. This can happen due to poor image quality,
///   unsupported formats, or internal extraction issues.
/// - ``imageEncodingFailure``: Indicates that the system failed to encode or convert an image
///   into the required format for processing (e.g., when preparing data for recognition).
/// - ``faceDetectionFailure``: Indicates that no face was detected or that face detection failed
///   due to occlusions, lighting conditions, or incompatible image inputs.
///
/// ## Usage:
/// - Use these errors to signal specific failures in your face recognition pipeline,
///   such as during preprocessing, detection, or template generation.
/// - Since the enum conforms to `LocalizedError`, you can present `error.localizedDescription`
///   directly to users for a localized, human-readable message.
///
/// ## Localization:
/// - The `errorDescription` uses `NSLocalizedString` for each case. Provide corresponding
///   entries in your `.strings` files to localize the error messages across supported locales.
public enum FaceRecognitionError: LocalizedError {
    
    case faceTemplateExtractionFailed, imageEncodingFailure, faceDetectionFailure
    
    public var errorDescription: String? {
        switch self {
        case .faceTemplateExtractionFailed:
            return NSLocalizedString("Face template extraction failed", comment: "")
        case .imageEncodingFailure:
            return NSLocalizedString("Image encoding failed", comment: "")
        case .faceDetectionFailure:
            return NSLocalizedString("Face detection failed", comment: "")
        }
    }
}
