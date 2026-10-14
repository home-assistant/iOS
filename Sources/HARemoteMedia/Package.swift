// swift-tools-version:5.9
import PackageDescription

// The Remote Now Playing model: how one `media_player` entity's attributes become what Now Playing
// shows, and how successive reports are reconciled. Kept in its own local package, and to system
// frameworks only, so the app and the RemoteMedia extension can share it later without pulling the
// Companion dependency graph into the extension.
let package = Package(
    name: "HARemoteMedia",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "HARemoteMedia", targets: ["HARemoteMedia"]),
    ],
    targets: [
        .target(
            name: "HARemoteMedia",
            path: "Sources"
        ),
    ]
)
