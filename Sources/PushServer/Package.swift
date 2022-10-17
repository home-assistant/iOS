// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PushServer",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/apns.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.5.0"),
        .package(name: "SharedPush", path: "SharedPush"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "SharedPush", package: "SharedPush"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "APNS", package: "apns"),
                .product(name: "Redis", package: "redis"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See
                // <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .executableTarget(
            name: "Run",
            dependencies: [
                .target(name: "App"),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "SharedPushTests",
            dependencies: [
                .product(name: "SharedPush", package: "SharedPush"),
            ],
            resources: [
                .copy("notification_test_cases.bundle"),
            ]
        ),
    ]
)
