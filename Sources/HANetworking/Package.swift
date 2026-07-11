// swift-tools-version:5.9
import PackageDescription

// The shared networking + server/credential layer, imported by every target so there is one
// implementation of "how we reach Home Assistant".
//
// PHASE 1 (now): a normal (static) library, linked ONLY into the two `Shared` framework targets — the
// same safe pattern as HAModels/HAIconic/HADesignSystem. Its code is absorbed into `Shared.framework`,
// so every `import Shared` consumer resolves the symbols with no per-target linking. No duplication,
// because it lives in exactly one image (Shared) per process.
//
// PHASE 2 (when the watch widget links this directly): flip the product to `type: .dynamic` and wire it
// into every consuming target + embed it (mirroring `Sources/PromiseKitDynamic/Package.swift`). That is
// required because a *static* Swift library linked into TWO Mach-O images (Shared.framework AND the
// widget, which can't link Shared) gives the runtime duplicate type-metadata / protocol conformances
// (Xcode 27 crashes in `swift_getAssociatedTypeWitnessSlow` on PromiseKit's `Thenable`). Deferred so the
// large 12-target link/embed wiring is done once, after all files are extracted.
//
// It has NO dependency on `Current`/HACore (that would be a cycle — HACore depends on HANetworking).
// The handful of app services these files need are injected via `HANetworkingEnvironment`, populated by
// HACore at launch. External deps are added as files that need them move in (kept out for the first,
// dependency-free `ClientCertificate` leaf).
let package = Package(
    name: "HANetworking",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "HANetworking", targets: ["HANetworking"]),
    ],
    dependencies: [
        // Pinned to the app's exact versions so Xcode's package graph unifies each into one instance
        // (a second copy of a static product would crash at runtime — see PromiseKitDynamic).
        .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.12.0"),
        .package(url: "https://github.com/tristanhimmelman/ObjectMapper.git", exact: "4.4.3"),
        .package(url: "https://github.com/home-assistant/HAKit.git", exact: "0.4.18"),
    ],
    targets: [
        .target(
            name: "HANetworking",
            dependencies: [
                "Alamofire",
                "ObjectMapper",
                .product(name: "HAKit", package: "HAKit"),
            ],
            path: "Sources"
        ),
    ]
)
