// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FaceRecognitionR300",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FaceRecognitionR300Cloud",
            targets: ["FaceRecognitionR300Cloud"]
        ),
        .library(
            name: "FaceRecognitionR300Core",
            targets: ["FaceRecognitionR300Core"]
        )
    ],
    dependencies: [
        // Alignment, from a package that carries nothing else. This used to come from
        // Face-Recognition-ArcFace-Apple, which also carries an ONNX Runtime face detector:
        // SwiftPM resolves dependencies per package, so every consumer of this core pulled
        // that detector in whether or not it was used.
        .package(url: "https://github.com/AppliedRecognition/Face-Alignment-Apple.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FaceRecognitionR300Cloud",
            dependencies: [
                "FaceRecognitionR300Core"
            ]
        ),
        .target(
            name: "FaceRecognitionR300Core",
            dependencies: [
                // Alignment only. This target used to depend on `FaceRecognitionArcFaceCore`
                // and `FaceDetectionRetinaFaceOrt` for a face re-detection pass that has been
                // removed to match Android, and then on `FaceAlignmentCore` inside that same
                // package, which still pulled the detector into this graph.
                .product(name: "FaceAlignmentCore", package: "Face-Alignment-Apple")
            ]
        ),
        .testTarget(
            name: "FaceRecognitionR300Tests",
            dependencies: ["FaceRecognitionR300Cloud", "FaceRecognitionR300Core"],
            resources: [.process("Resources")]
        ),
    ]
)
