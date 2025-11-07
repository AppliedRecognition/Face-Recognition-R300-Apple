# Face recognition for iOS using R300 model

## Requirements

Runs on iOS 15 or newer

## Installation


Add the package to your `Package.swift` (typically in your test target):

```swift
dependencies: [
    .package(url: "Face-Recognition-R300-Apple", .upToNextMajor(from: "1.0.0"))
]
```

Then import:

```swift
import FaceRecognitionR300Core
import FaceRecognitionR300Cloud
```

## Usage

The library requires an API key. You can obtain the API key by [contacting Applied Recognition](mailto:support@appliedrecognition.com). The project’s test target includes a rate-limited API key to use for testing. You’re welcome to use the API key in your test/demo projects but it’s not suitable for production use.

### Examples

#### Extract face templates from faces in image

```swift
import Foundation
import UIKit
import VerIDCommonTypes
import FaceDetectionRetinaFaceOrt
import FaceRecognitionR300Core
import FaceRecognitionR300Cloud

func extractFaceTemplatesFromImage(_ image: UIImage, limit: Int = 5) async throws -> [FaceTemplate<R300,[Float]>] {
    let recognition = FaceRecognitionR300(apiKey: "<my API key>", url: URL(string: "<server URL>")!)
    let detection = try FaceDetectionRetinaFaceOrt()
    let verIDImage = try image.toVerIDImage()
    let faces = try await detection.detectFacesInImage(verIDImage, limit: limit)
    return try await recognition.createFaceRecognitionTemplates(from: faces, in: verIDImage)
}
```

#### Compare face templates

```swift
import Foundation
import VerIDCommonTypes
import FaceRecognitionR300Core
import FaceRecognitionR300Cloud


func compareFaceTemplate(_ template1: FaceTemplate<R300, [Float]>, to template2: FaceTemplate<R300, [Float]>) async throws -> Float {
    let recognition = FaceRecognitionR300(apiKey: "<my API key>", url: URL(string: "<server URL>")!)
    guard let score = try await recognition.compareFaceRecognitionTemplates([template1], to: template2).first else {
        throw NSError(domain: "FaceRecognitionR300", code: 0, userInfo: nil)
    }
    return score
}
```