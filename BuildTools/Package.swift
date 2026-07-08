// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.53.1"),
        .package(url: "https://github.com/SwiftGen/SwiftGen", exact: "6.5.1"),
    ],
    targets: [
        .binaryTarget(
            name: "SwiftLintBinary",
            url: "https://github.com/realm/SwiftLint/releases/download/0.54.0/SwiftLintBinary-macos.artifactbundle.zip",
            checksum: "963121d6babf2bf5fd66a21ac9297e86d855cbc9d28322790646b88dceca00f1"
        ),
        .target(name: "BuildTools"),
    ]
)
