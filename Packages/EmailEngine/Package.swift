// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmailEngine",
    platforms: [
        .iOS(.v18),
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
        .target(
            name: "EmailEngine",
            dependencies: [
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            ]
        ),
    ]
)
