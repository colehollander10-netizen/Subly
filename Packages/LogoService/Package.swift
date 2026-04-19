// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LogoService",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(name: "LogoService", targets: ["LogoService"]),
    ],
    targets: [
        .target(name: "LogoService"),
    ]
)
