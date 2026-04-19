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
    targets: [
        .target(name: "EmailEngine"),
    ]
)
