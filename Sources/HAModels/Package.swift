// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HAModels",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "HAModels", targets: ["HAModels"]),
    ],
    dependencies: [
        // Pinned to the exact version the app resolves so Xcode's package graph unifies both into a
        // single GRDB instance (a second copy of a static product would crash at runtime).
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.8.0"),
    ],
    targets: [
        .target(
            name: "HAModels",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources"
        ),
    ]
)
