// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HAIconic",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "HAIconic", targets: ["HAIconic"]),
    ],
    targets: [
        .target(
            name: "HAIconic",
            path: "Sources",
            resources: [
                .copy("Resources/MaterialDesignIcons.ttf"),
            ]
        ),
    ]
)
