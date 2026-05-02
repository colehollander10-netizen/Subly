// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OCRCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "OCRCore", targets: ["OCRCore"]),
    ],
    targets: [
        .target(name: "OCRCore"),
        .testTarget(
            name: "OCRCoreTests",
            dependencies: ["OCRCore"]
        ),
    ]
)
