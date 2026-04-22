// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmailEngine",
    platforms: [
        .iOS(.v18),
        .macOS(.v11),
    ],
    products: [
        .library(name: "EmailEngine", targets: ["EmailEngine"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/google/GoogleSignIn-iOS",
            from: "8.0.0"
        ),
    ],
    targets: [
        .target(name: "EmailParsingCore"),
        .target(
            name: "EmailEngine",
            dependencies: [
                "EmailParsingCore",
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            ]
        ),
        .testTarget(
            name: "EmailEngineTests",
            dependencies: ["EmailParsingCore"]
        ),
    ]
)
