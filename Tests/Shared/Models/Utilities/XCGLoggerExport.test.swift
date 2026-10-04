#if os(iOS)
import Foundation
@testable import Shared
import UIKit
import XCGLogger
import XCTest

final class XCGLoggerExportTests: XCTestCase {
    private final class PresentationRecordingViewController: UIViewController {
        var presented: [UIViewController] = []

        override func present(
            _ viewControllerToPresent: UIViewController,
            animated flag: Bool,
            completion: (() -> Void)? = nil
        ) {
            presented.append(viewControllerToPresent)
        }
    }

    private var originalIsCatalyst: Bool!
    private var logFileURL: URL!
    private var createdArchives: [URL] = []

    override func setUp() {
        super.setUp()
        originalIsCatalyst = Current.isCatalyst
        logFileURL = AppConstants.LogsDirectory
            .appendingPathComponent("coverage-\(UUID().uuidString).log", isDirectory: false)
        try? Data("log line\n".utf8).write(to: logFileURL)
    }

    override func tearDown() {
        Current.isCatalyst = originalIsCatalyst
        try? FileManager.default.removeItem(at: logFileURL)
        for url in createdArchives {
            try? FileManager.default.removeItem(at: url)
        }
        createdArchives = []
        super.tearDown()
    }

    func testExportTitleDependsOnCatalyst() {
        Current.isCatalyst = true
        XCTAssertEqual(Current.Log.exportTitle, L10n.Settings.Developer.ShowLogFiles.title)

        Current.isCatalyst = false
        XCTAssertEqual(Current.Log.exportTitle, L10n.Settings.Developer.ExportLogFiles.title)
    }

    func testArchiveURLOnCatalystIsLogsDirectory() {
        Current.isCatalyst = true
        XCTAssertEqual(Current.Log.archiveURL(), AppConstants.LogsDirectory)
    }

    func testArchiveURLCreatesZipInTemporaryDirectory() throws {
        Current.isCatalyst = false

        let archiveURL = try XCTUnwrap(Current.Log.archiveURL())
        createdArchives.append(archiveURL)

        XCTAssertTrue(archiveURL.lastPathComponent.hasSuffix(".logs.zip"))
        XCTAssertEqual(
            archiveURL.deletingLastPathComponent().standardizedFileURL,
            FileManager.default.temporaryDirectory.standardizedFileURL
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))

        let size = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? NSNumber
        )
        XCTAssertGreaterThan(size.intValue, 0)
    }

    @MainActor
    func testExportOnCatalystOpensLogsDirectory() {
        Current.isCatalyst = true
        let source = PresentationRecordingViewController()

        var opened: [URL] = []
        Current.Log.export(from: source, sender: UIView()) { opened.append($0) }

        XCTAssertEqual(opened, [AppConstants.LogsDirectory])
        XCTAssertTrue(source.presented.isEmpty)
    }

    private func zipArchivesInTemporaryDirectory() throws -> Set<URL> {
        try Set(
            FileManager.default
                .contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasSuffix(".logs.zip") }
        )
    }

    @MainActor
    func testExportPresentsShareSheetAndRemovesArchiveWhenDone() throws {
        Current.isCatalyst = false
        let source = PresentationRecordingViewController()
        let sender = UIView()
        let before = try zipArchivesInTemporaryDirectory()

        var opened: [URL] = []
        Current.Log.export(from: source, sender: sender) { opened.append($0) }

        let newArchives = try zipArchivesInTemporaryDirectory().subtracting(before)
        createdArchives.append(contentsOf: newArchives)
        let archive = try XCTUnwrap(newArchives.first)
        XCTAssertEqual(newArchives.count, 1)
        XCTAssertTrue(opened.isEmpty)

        XCTAssertEqual(source.presented.count, 1)
        let controller = try XCTUnwrap(source.presented.first as? UIActivityViewController)
        let handler = try XCTUnwrap(controller.completionWithItemsHandler)

        // Picked an activity that hasn't completed: the archive must stay around.
        handler(.copyToPasteboard, false, nil, nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))

        // Completing the share removes the archive.
        handler(.copyToPasteboard, true, nil, nil)
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.path))
    }

    @MainActor
    func testExportRemovesArchiveWhenShareSheetIsCancelled() throws {
        Current.isCatalyst = false
        let source = PresentationRecordingViewController()
        let before = try zipArchivesInTemporaryDirectory()

        Current.Log.export(from: source, sender: UIView()) { _ in }

        let newArchives = try zipArchivesInTemporaryDirectory().subtracting(before)
        createdArchives.append(contentsOf: newArchives)
        let archive = try XCTUnwrap(newArchives.first)
        let controller = try XCTUnwrap(source.presented.first as? UIActivityViewController)

        controller.completionWithItemsHandler?(nil, false, nil, nil)
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.path))
    }
}
#endif
