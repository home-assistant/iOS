import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit

/// Minimal on-watchOS snapshot assertion.
///
/// swift-snapshot-testing's SwiftUI image strategy relies on `UIHostingController`/`UIWindow`, which
/// don't exist on watchOS, so `SharedTesting.assertSnapshot` can't run here. Instead we rasterize the
/// view with `ImageRenderer` (watchOS 9+) and compare PNGs ourselves, recording a missing reference
/// (and failing) on first run — the same record-then-assert flow snapshot-testing uses.
///
/// Set the `RECORD_SNAPSHOTS` environment variable to overwrite references.
@MainActor
func assertWatchSnapshot(
    _ view: some View,
    named: String,
    scale: CGFloat = 2,
    perPixelTolerance: Int = 12,
    differingPixelRatio: Double = 0.02,
    filePath: StaticString = #filePath
) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let image = renderer.uiImage, let pngData = image.pngData() else {
        Issue.record("Failed to rasterize view for snapshot \"\(named)\".")
        return
    }

    let referenceURL = Self_referenceURL(filePath: filePath, named: named)
    let fileManager = FileManager.default
    let shouldRecord = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil

    // Record mode (RECORD_SNAPSHOTS) overwrites the reference; a missing reference is recorded and then
    // reported so the run fails until there is something to assert against.
    let referenceExists = fileManager.fileExists(atPath: referenceURL.path)
    if shouldRecord || !referenceExists {
        write(pngData, to: referenceURL)
        Issue.record(
            referenceExists
                ? "Recorded snapshot (RECORD_SNAPSHOTS) at \(referenceURL.path)."
                : "No reference found on disk; recorded snapshot at \(referenceURL.path). Re-run to assert."
        )
        return
    }

    guard let referenceData = try? Data(contentsOf: referenceURL),
          let referenceImage = UIImage(data: referenceData)?.cgImage,
          let newImage = image.cgImage else {
        Issue.record("Could not load reference or rendered image for \"\(named)\".")
        return
    }

    if let diff = compare(
        referenceImage,
        newImage,
        perPixelTolerance: perPixelTolerance,
        differingPixelRatio: differingPixelRatio
    ) {
        let failureURL = referenceURL.deletingPathExtension().appendingPathExtension("failure.png")
        write(pngData, to: failureURL)
        Issue
            .record(
                "Snapshot \"\(named)\" did not match reference: \(diff) Failed render written to \(failureURL.path)."
            )
    }
}

/// `<test file dir>/__Snapshots__/<test file name>/<named>.png`, matching swift-snapshot-testing's layout.
private func Self_referenceURL(filePath: StaticString, named: String) -> URL {
    let fileURL = URL(fileURLWithPath: "\(filePath)")
    let testName = fileURL.deletingPathExtension().lastPathComponent
    return fileURL
        .deletingLastPathComponent()
        .appendingPathComponent("__Snapshots__", isDirectory: true)
        .appendingPathComponent(testName, isDirectory: true)
        .appendingPathComponent("\(named).png")
}

@MainActor
private func write(_ data: Data, to url: URL) {
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    } catch {
        Issue.record("Failed to write snapshot to \(url.path): \(error)")
    }
}

/// Returns a human-readable reason when the two images differ beyond the tolerances, else nil.
private func compare(
    _ a: CGImage,
    _ b: CGImage,
    perPixelTolerance: Int,
    differingPixelRatio: Double
) -> String? {
    guard a.width == b.width, a.height == b.height else {
        return "size \(b.width)x\(b.height) vs reference \(a.width)x\(a.height)."
    }
    guard let pixelsA = rgbaBytes(a), let pixelsB = rgbaBytes(b), pixelsA.count == pixelsB.count else {
        return "could not read pixel data."
    }
    var differing = 0
    var index = 0
    while index < pixelsA.count {
        let delta = abs(Int(pixelsA[index]) - Int(pixelsB[index]))
        if delta > perPixelTolerance { differing += 1 }
        index += 1
    }
    let ratio = Double(differing) / Double(pixelsA.count)
    return ratio > differingPixelRatio
        ? "\(Int(ratio * 100))% of channel samples differ (allowed \(Int(differingPixelRatio * 100))%)."
        : nil
}

private func rgbaBytes(_ image: CGImage) -> [UInt8]? {
    let width = image.width, height = image.height
    let bytesPerRow = width * 4
    var data = [UInt8](repeating: 0, count: bytesPerRow * height)
    guard let context = CGContext(
        data: &data,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return data
}
