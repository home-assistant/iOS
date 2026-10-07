// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HAWatchCommunicationMessages",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "HAWatchCommunicationMessages", targets: ["HAWatchCommunicationMessages"]),
    ],
    targets: [
        .target(
            name: "HAWatchCommunicationMessages",
            path: "Sources"
        ),
    ]
)
