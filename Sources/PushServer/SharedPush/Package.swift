// swift-tools-version:5.5
import PackageDescription

// Separate package so the app doesn't need to pull in packages
public let package = Package(
    name: "SharedPush",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14),
        .tvOS(.v12),
        .watchOS(.v5),
    ],
    products: [
        .library(name: "SharedPush", targets: ["SharedPush"]),
    ],
    targets: [
        .target(name: "SharedPush", path: "Sources"),
    ]
)
