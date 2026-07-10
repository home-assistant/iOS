// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HADesignSystem",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "HADesignSystem", targets: ["HADesignSystem"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", .upToNextMajor(from: "5.3.0")),
    ],
    targets: [
        .target(
            name: "HADesignSystem",
            dependencies: ["SFSafeSymbols"],
            path: "Sources"
        ),
        .testTarget(
            name: "HADesignSystemTests",
            dependencies: ["HADesignSystem"],
            path: "Tests"
        ),
    ]
)
