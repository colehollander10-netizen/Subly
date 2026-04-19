// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrialEngine",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(name: "TrialEngine", targets: ["TrialEngine"]),
    ],
    targets: [
        .target(name: "TrialEngine"),
    ]
)
