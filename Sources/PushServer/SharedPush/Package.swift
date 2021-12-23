// swift-tools-version:5.3

import PackageDescription

/// The Package
public let package = Package(
    name: "SharedPush",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14),
        .tvOS(.v12),
        .watchOS(.v5),
    ],
    products: [
        .library(
            name: "SharedPush",
            targets: ["SharedPush"]
        ),
    ],
    targets: [
        .target(
            name: "SharedPush",
            path: "Sources"
        ),
        .testTarget(
            name: "Tests",
            dependencies: [
                .byName(name: "SharedPush"),
            ],
            path: "Tests",
            resources: [
                .copy("notification_test_cases.bundle"),
            ]
        ),
    ]
)
