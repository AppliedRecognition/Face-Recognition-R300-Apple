//
//  File.swift
//  Face-Recognition-R300
//
//  Created by Jakub Dolejs on 28/10/2025.
//

import Foundation
import UIKit
import VerIDCommonTypes
@_spi(Testing) import FaceRecognitionR300Core

/// A concrete implementation of `FaceRecognitionR300Core` that communicates with a remote
/// R300 face recognition service to extract face templates from already-aligned face images.
///
/// ## Overview
/// - ``FaceRecognitionR300`` wraps a network-based face template extraction flow. It takes aligned
///   face images (`UIImage` instances), encodes them, and sends them to a server that implements
///   the R300 face recognition API. The server responds with serialized face templates that can
///   be used for matching and verification.
/// - This class relies on an API key and a server URL. You can provide them explicitly via the
///   designated initializer, or place them in the app’s Info.plist for the convenience initializer
///   to pick up automatically.
///
/// ## Initialization
/// - Designated initializer:
///   - ``init(apiKey:url:)`` lets you specify the API key and server URL at runtime.
/// - Convenience initializer:
///   - ``init()`` reads the following Info.plist keys:
///     - `com.appliedrec.face-recognition-r300.apiKey` (String)
///     - `com.appliedrec.face-recognition-r300.serverUrl` (String URL)
///   - Throws ``FaceRecognitionInitializationError`` if the keys are missing or invalid.
///
/// ## Behavior
/// - createFaceRecognitionTemplatesFromAlignedFaceImages(_:) (overridden)
///   - Accepts an array of aligned face UIImages.
///   - Encodes images as JPEG and POSTs them as JSON to the configured server URL, using the
///     API key in the x-api-key header.
///   - Decodes the response into an array of `FaceTemplate<R300, [Float]>`.
///   - Throws FaceRecognitionError if image encoding fails or the server responds with an error
///     (HTTP status code >= 400), or if decoding fails.
///
/// ## Requirements
/// - Images must already be aligned according to the R300 specification before calling the
///   template extraction method.
/// - A valid API key and server endpoint must be provided.
///
/// ## Errors
/// - FaceRecognitionInitializationError:
///   - .missingAPIKey: The API key is not present in the Info.plist.
///   - .missingServerURL: The server URL is not present in the Info.plist.
///   - .invalidServerURL(String): The server URL string is malformed.
/// - FaceRecognitionError:
///   - .imageEncodingFailure: A provided UIImage could not be converted to JPEG.
///   - .faceTemplateExtractionFailed: The remote service returned an error status code.
///
/// ## Threading
/// - Network operations are performed with async/await using URLSession. Callers should await the
///   result on an async context.
///
/// ## Example
/// - Using explicit configuration:
///   ```swift
///   let recognizer = FaceRecognitionR300(apiKey: "<your-api-key>", url: URL(string: "<server-url>")!)
///   ```
/// - Using Info.plist configuration:
///   ```swift
///   let recognizer = try FaceRecognitionR300()
///   ```
public class FaceRecognitionR300: FaceRecognitionR300Core {
    
    let apiKey: String
    let url: URL
    
    /// Creates a new instance configured to communicate with a remote R300 face recognition service.
    ///
    /// Use this designated initializer when you want to supply the API key and server URL at runtime,
    /// rather than relying on values stored in the app’s Info.plist. The instance will use the provided
    /// credentials to send aligned face images to the server and receive serialized face templates.
    ///
    /// - Parameters:
    ///   - apiKey: The API key used to authenticate requests to the R300 face recognition server.
    ///   - url: The base URL of the R300 face recognition service endpoint that performs template extraction.
    /// - SeeAlso: ``init()`` for an initializer that reads configuration from the app’s Info.plist.
    public init(apiKey: String, url: URL) {
        self.apiKey = apiKey
        self.url = url
        try! super.init()
    }
    
    /// Creates a new FaceRecognitionR300 instance using configuration values from the app’s Info.plist.
    /// 
    /// This convenience initializer reads the following keys from the main bundle’s Info.plist:
    /// - `com.appliedrec.face-recognition-r300.apiKey` (String): The API key used to authenticate requests
    ///   to the R300 face recognition service.
    /// - `com.appliedrec.face-recognition-r300.serverUrl` (String): The base URL of the R300 face recognition
    ///   service endpoint used for template extraction.
    /// 
    /// - Throws:
    ///   - ``FaceRecognitionInitializationError/missingAPIKey`` if the API key is not present.
    ///   - ``FaceRecognitionInitializationError/missingServerURL`` if the server URL is not present.
    ///   - ``FaceRecognitionInitializationError/invalidServerURL(_:)`` if the server URL string is malformed.
    ///
    /// Use this initializer when you prefer to configure the recognizer via Info.plist rather than passing
    /// values at runtime. For explicit configuration, use ``init(apiKey:url:)``.
    public convenience override init() throws {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "com.appliedrec.face-recognition-r300.apiKey") as? String else {
            throw FaceRecognitionInitializationError.missingAPIKey
        }
        guard let serverUrl = Bundle.main.object(forInfoDictionaryKey: "com.appliedrec.face-recognition-r300.serverUrl") as? String else {
            throw FaceRecognitionInitializationError.missingServerURL
        }
        guard let url = URL(string: serverUrl) else {
            throw FaceRecognitionInitializationError.invalidServerURL(serverUrl)
        }
        self.init(apiKey: apiKey, url: url)
    }
    
    @_spi(Testing)
    public override func createFaceRecognitionTemplatesFromAlignedFaceImages(_ images: [UIImage]) async throws -> [FaceTemplate<R300, [Float]>] {
        let body = try self.requestBodyFromFaceImages(images)
        var request = URLRequest(url: self.url)
        request.httpMethod = "POST"
        request.addValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode < 400 else {
            throw FaceRecognitionError.faceTemplateExtractionFailed
        }
        return try JSONDecoder().decode([FaceTemplate<R300,[Float]>].self, from: data)
    }
    
    private func requestBodyFromFaceImages(_ images: [UIImage]) throws -> Data {
        let encodedImages = try images.map { image in
            guard let jpeg = image.jpegData(compressionQuality: 1.0) else {
                throw FaceRecognitionError.imageEncodingFailure
            }
            return jpeg
        }
        return try JSONEncoder().encode(RequestBody(images: encodedImages))
    }
}


fileprivate struct RequestBody: Encodable {
    let images: [Data]
}

/// Errors that can occur while initializing a FaceRecognitionR300 instance from the app’s Info.plist.
///
/// Use these cases to diagnose configuration issues when calling the convenience initializer that
/// reads the API key and server URL from the Info.plist.
///
/// - missingAPIKey:
///   The key `com.appliedrec.face-recognition-r300.apiKey` was not found or is not a String in the
///   app’s Info.plist. Provide a valid API key to authenticate requests to the R300 service.
///
/// - missingServerURL:
///   The key `com.appliedrec.face-recognition-r300.serverUrl` was not found or is not a String in the
///   app’s Info.plist. Provide a valid base URL for the R300 face recognition endpoint.
///
/// - invalidServerURL(String):
///   The value found under `com.appliedrec.face-recognition-r300.serverUrl` could not be parsed into a
///   valid URL. The associated String contains the invalid value to aid debugging.
///
/// ## Conformance:
/// - LocalizedError: Provides human-readable descriptions suitable for displaying to users or logging.
///
/// ## Typical usage:
///
/// ```swift
/// do {
///     let recognizer = try FaceRecognitionR300() // reads from Info.plist
/// } catch let error as FaceRecognitionInitializationError {
///     // Handle specific configuration problems here
///     print(error.localizedDescription)
/// }
/// ```
///
/// ## Info.plist keys:
/// - `com.appliedrec.face-recognition-r300.apiKey`: String
/// - `com.appliedrec.face-recognition-r300.serverUrl`: String (URL-formatted)
public enum FaceRecognitionInitializationError: LocalizedError {
    case missingAPIKey, missingServerURL, invalidServerURL(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing API key in info dictionary"
        case .missingServerURL:
            return "Missing server URL in info dictionary"
        case .invalidServerURL(let url):
            return "Server URL \(url) in the info dictionary is invalid"
        }
    }
}
