// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HAWatchComplications",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "HAWatchComplications", targets: ["HAWatchComplications"]),
    ],
    targets: [
        .target(
            name: "HAWatchComplications",
            path: "Sources"
        ),
    ]
)
