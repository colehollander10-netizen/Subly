// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MascotKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MascotKit", targets: ["MascotKit"]),
    ],
    targets: [
        .target(
            name: "MascotKit",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MascotKitTests",
            dependencies: ["MascotKit"]
        ),
    ]
)
