// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SubscriptionStore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SubscriptionStore", targets: ["SubscriptionStore"]),
    ],
    targets: [
        .target(name: "SubscriptionStore"),
        .testTarget(
            name: "SubscriptionStoreTests",
            dependencies: ["SubscriptionStore"]
        ),
    ]
)
