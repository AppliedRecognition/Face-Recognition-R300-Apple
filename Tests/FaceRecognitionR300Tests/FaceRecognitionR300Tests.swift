import Testing
import Foundation
import UIKit
import VerIDCommonTypes
import FaceDetectionRetinaFaceOrt
import FaceRecognitionR300Core
@testable import FaceRecognitionR300Cloud

@Test("Extract face template")
func extractFaceTemplate() async throws {
    let faceRecognition = try createFaceRecognition()
    let faceDetection = try FaceDetectionRetinaFaceOrt()
    let image = try createTestImage()
    let face = try #require(try await faceDetection.detectFacesInImage(image, limit: 1).first)
    let template = try #require(try await faceRecognition.createFaceRecognitionTemplates(from: [face], in: image).first)
    #expect(template.version == R300.id)
    #expect(template.data.count == 512)
}

fileprivate func createFaceRecognition() throws -> FaceRecognitionR300 {
    let configUrl = try #require(Bundle.module.url(forResource: "config", withExtension: "json"))
    let data = try Data(contentsOf: configUrl)
    let config = try JSONDecoder().decode(Config.self, from: data)
    let url = try #require(URL(string: config.serverUrl))
    return FaceRecognitionR300(apiKey: config.apiKey, url: url)
}

fileprivate func createTestImage() throws -> Image {
    let imageUrl = try #require(Bundle.module.url(forResource: "Photo 04-05-2016, 18 57 50", withExtension: "png"))
    let data = try Data(contentsOf: imageUrl)
    let uiImage = try #require(UIImage(data: data))
    let image = try #require(Image(uiImage: uiImage))
    return image
}

fileprivate struct Config: Decodable {
    let apiKey: String
    let serverUrl: String
}
