// swift-tools-version:5.7
import PackageDescription

// Dynamic wrapper around PromiseKit.
//
// PromiseKit (mxcl/PromiseKit) only vends a *static* library product. When a
// static Swift library is linked into more than one Mach-O image in the same
// process (here: the App/extension binary AND Shared.framework), the Swift
// runtime ends up with duplicate type-metadata / protocol-conformance records.
// Older toolchains tolerated this; the Xcode 27 runtime crashes in
// `swift_getAssociatedTypeWitnessSlow` while resolving `Thenable`.
//
// This package re-exports PromiseKit through a product declared explicitly
// `.dynamic`, so PromiseKit's code lives in a single shared framework that
// every target links against — one copy of the metadata, no crash, and the
// symbols resolve at link time (which a static lib absorbed into the dynamic
// Shared.framework does not provide).
public let package = Package(
    name: "PromiseKitDynamic",
    platforms: [
        .iOS(.v16),
        .macOS(.v12),
        .tvOS(.v12),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "PromiseKitDynamic", type: .dynamic, targets: ["PromiseKitDynamic"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/PromiseKit/", exact: "8.1.1"),
    ],
    targets: [
        .target(
            name: "PromiseKitDynamic",
            dependencies: [
                .product(name: "PromiseKit", package: "PromiseKit"),
            ],
            path: "Sources"
        ),
    ]
)
