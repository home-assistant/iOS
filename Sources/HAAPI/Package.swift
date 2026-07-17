// swift-tools-version:6.0
import PackageDescription

// HAAPI is the modern, dependency-free Home Assistant websocket client built on
// URLSessionWebSocketTask — the long-term replacement for HAKit/Starscream, and the only
// client that can run on watchOS (Starscream cannot). Pure async/await + AsyncStream,
// actor-based, Swift 6 strict concurrency.
//
// Keep this package at ZERO dependencies: the app injects URLs, tokens, and TLS-capable
// URLSessions from the outside (see HAAPIConfiguration), so nothing here ever needs to know
// about Server/TokenManager/ConnectionInfo or drag GRDB/Alamofire into the graph.
let package = Package(
    name: "HAAPI",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
        // Not linked into any macOS target; declared so `swift build/test --package-path
        // Sources/HAAPI` works from the CLI (which builds for the host).
        .macOS(.v13),
    ],
    products: [
        .library(name: "HAAPI", targets: ["HAAPI"]),
    ],
    targets: [
        .target(
            name: "HAAPI",
            path: "Sources"
        ),
        .testTarget(
            name: "HAAPITests",
            dependencies: ["HAAPI"],
            path: "Tests"
        ),
    ]
)
