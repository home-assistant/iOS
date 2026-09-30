// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HAUtilities",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "HAUtilities", targets: ["HAUtilities"]),
    ],
    targets: [
        .target(
            name: "HAUtilities",
            path: "Sources"
        ),
    ]
)
