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
        .package(url: "https://github.com/AppliedRecognition/Face-Recognition-ArcFace-Apple.git", .upToNextMajor(from: "1.2.2"))
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
                .product(name: "FaceRecognitionArcFaceCore", package: "Face-Recognition-ArcFace-Apple"),
                .product(name: "FaceDetectionRetinaFaceOrt", package: "Face-Recognition-ArcFace-Apple")
            ]
        ),
        .testTarget(
            name: "FaceRecognitionR300Tests",
            dependencies: ["FaceRecognitionR300Cloud", "FaceRecognitionR300Core"],
            resources: [.process("Resources")]
        ),
    ]
)
