// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrialParsingCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "TrialParsingCore", targets: ["TrialParsingCore"]),
    ],
    targets: [
        .target(name: "TrialParsingCore"),
        .testTarget(
            name: "TrialParsingCoreTests",
            dependencies: ["TrialParsingCore"]
        ),
    ]
)
