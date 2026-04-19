// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotificationEngine",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(name: "NotificationEngine", targets: ["NotificationEngine"]),
    ],
    targets: [
        .target(name: "NotificationEngine"),
    ]
)
