// swift-tools-version:5.9
import PackageDescription

// A small local package for the secretbox primitive Home Assistant's `mobile_app` webhook seals
// payloads with, kept separate from `Shared` so lightweight targets can depend on it without the
// full Shared module.
let package = Package(
    name: "WebhookCrypto",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "WebhookCrypto", targets: ["WebhookCrypto"]),
    ],
    dependencies: [
        // Pinned to the app's exact version so Xcode's package graph unifies it into one instance.
        .package(url: "https://github.com/jedisct1/swift-sodium", exact: "0.11.0"),
    ],
    targets: [
        .target(
            name: "WebhookCrypto",
            dependencies: [
                .product(name: "Sodium", package: "swift-sodium"),
            ],
            path: "Sources"
        ),
    ]
)
