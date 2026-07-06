// swift-tools-version:5.7
import PackageDescription

// Separate package so the app doesn't need to pull in packages
public let package = Package(
    name: "SharedPush",
    platforms: [
        .iOS(.v16),
        .macOS(.v12),
        .tvOS(.v12),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "SharedPush", targets: ["SharedPush"]),
    ],
    targets: [
        .target(name: "SharedPush", path: "Sources"),
    ]
)
