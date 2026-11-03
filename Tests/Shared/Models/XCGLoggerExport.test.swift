import Foundation
@testable import Shared
import SharedTesting
import Testing
import UIKit
import XCGLogger
import ZIPFoundation

/// Log export: the archive it builds and the share sheet (or Finder hand-off on Catalyst) around it.
/// On the main actor because the tests build UIKit views and controllers, including a real
/// `UIActivityViewController`.
@MainActor
@Suite(.isolatedEnvironment, .serialized)
struct XCGLoggerExportTests {
    /// Captures what `export` presents instead of needing a window to present it in.
    private final class CapturingController: UIViewController {
        var presented: UIViewController?
        override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
            presented = controller
        }
    }

    private func zipArchives() -> [URL] {
        let directory = FileManager.default.temporaryDirectory
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ??
            []
        return contents.filter { $0.lastPathComponent.hasSuffix(".logs.zip") }
    }

    @Test func titleDependsOnThePlatform() {
        Current.isCatalyst = false
        let ios = Current.Log.exportTitle
        Current.isCatalyst = true
        let catalyst = Current.Log.exportTitle
        #expect(!ios.isEmpty)
        #expect(ios != catalyst)
    }

    @Test func archiveIsAZipOfTheLogs() throws {
        Current.isCatalyst = false
        try FileManager.default.createDirectory(at: AppConstants.LogsDirectory, withIntermediateDirectories: true)
        let marker = AppConstants.LogsDirectory.appendingPathComponent("xcglogger-export-test.log")
        try Data("hello".utf8).write(to: marker)
        defer { try? FileManager.default.removeItem(at: marker) }

        let url = try #require(Current.Log.archiveURL())
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "zip")

        let archive = try Archive(url: url, accessMode: .read, pathEncoding: nil)
        #expect(archive["xcglogger-export-test.log"] != nil)
    }

    @Test func catalystHandsTheLogsDirectoryToFinder() {
        Current.isCatalyst = true
        #expect(Current.Log.archiveURL() == AppConstants.LogsDirectory)

        var opened: [URL] = []
        Current.Log.export(from: CapturingController(), sender: UIView(), openURLHandler: { opened.append($0) })
        #expect(opened == [AppConstants.LogsDirectory])
    }

    @Test func iOSPresentsAShareSheetThatCleansUpAfterItself() throws {
        Current.isCatalyst = false
        let before = Set(zipArchives())
        let source = CapturingController()
        Current.Log.export(from: source, sender: UIView(), openURLHandler: { _ in Issue.record("not on iOS") })

        let sheet = try #require(source.presented as? UIActivityViewController)
        let created = zipArchives().filter { !before.contains($0) }
        #expect(!created.isEmpty)

        // Cancelling the sheet deletes the archive it was offered.
        sheet.completionWithItemsHandler?(nil, false, nil, nil)
        let remaining = zipArchives().filter { !before.contains($0) }
        #expect(remaining.count < created.count)
        for url in remaining {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
