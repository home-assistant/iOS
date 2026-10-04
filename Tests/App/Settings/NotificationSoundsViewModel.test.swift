import Foundation
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Notification sounds live in `~/Library/Sounds`; the screen lists, plays, imports and deletes them.
@MainActor
final class NotificationSoundsViewModelTests: XCTestCase {
    private var createdFiles: [URL] = []

    override func tearDown() async throws {
        for file in createdFiles {
            try? FileManager.default.removeItem(at: file)
        }
        createdFiles = []
    }

    /// Drops a file into the sounds folder, removed again in `tearDown`.
    private func makeSoundFile(extension pathExtension: String) throws -> URL {
        let viewModel = NotificationSoundsViewModel()
        let url = try viewModel.librarySoundsURL()
            .appendingPathComponent("ha-coverage-\(UUID().uuidString).\(pathExtension)")
        try Data("not really audio".utf8).write(to: url)
        createdFiles.append(url)
        return url
    }

    func testLibrarySoundsFolderIsCreated() throws {
        let url = try NotificationSoundsViewModel().librarySoundsURL()

        XCTAssertEqual(url.lastPathComponent, "Sounds")
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testLoadingListsImportedAndSystemSoundsSeparately() throws {
        let wav = try makeSoundFile(extension: "wav")
        let caf = try makeSoundFile(extension: "caf")
        let viewModel = NotificationSoundsViewModel()

        viewModel.loadSounds()

        XCTAssertTrue(viewModel.imported.map(\.lastPathComponent).contains(wav.lastPathComponent))
        XCTAssertFalse(viewModel.imported.map(\.lastPathComponent).contains(caf.lastPathComponent))
        XCTAssertTrue(viewModel.system.map(\.lastPathComponent).contains(caf.lastPathComponent))
        XCTAssertFalse(viewModel.system.map(\.lastPathComponent).contains(wav.lastPathComponent))
        XCTAssertTrue(viewModel.imported.allSatisfy { $0.pathExtension == "wav" })
        XCTAssertTrue(viewModel.system.allSatisfy { $0.pathExtension == "caf" })

        let importedNames = viewModel.imported.map(\.lastPathComponent)
        XCTAssertEqual(importedNames, importedNames.sorted())
        let bundledNames = viewModel.bundled.map(\.lastPathComponent)
        XCTAssertEqual(bundledNames, bundledNames.sorted())
        XCTAssertFalse(viewModel.isBusy)
    }

    func testDeletingASoundRemovesTheFileAndTheRow() throws {
        let wav = try makeSoundFile(extension: "wav")
        let viewModel = NotificationSoundsViewModel()
        viewModel.loadSounds()
        let listed = try XCTUnwrap(viewModel.imported.first(where: { $0.lastPathComponent == wav.lastPathComponent }))

        try viewModel.deleteSound(listed)

        XCTAssertFalse(viewModel.imported.contains(listed))
        XCTAssertFalse(FileManager.default.fileExists(atPath: wav.path))
    }

    func testDeletingAMissingSoundThrows() {
        let viewModel = NotificationSoundsViewModel()
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).wav")

        do {
            try viewModel.deleteSound(missing)
            XCTFail("Deleting a file that doesn't exist should throw")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testPlayingAnUnreadableFileReportsTheError() {
        let viewModel = NotificationSoundsViewModel()
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).wav")
        var reportedError: Error?

        viewModel.play(url: missing) { reportedError = $0 }
        viewModel.stopPlayback()

        XCTAssertNotNil(reportedError)
    }

    func testImportingAnUnsupportedFileReportsAConversionError() async {
        let viewModel = NotificationSoundsViewModel()
        let unsupported = FileManager.default.temporaryDirectory
            .appendingPathComponent("ha-coverage-\(UUID().uuidString).unsupported")
        var reportedErrors: [Error] = []

        await viewModel.importPickedFiles([unsupported]) { error in
            reportedErrors.append(error)
        }

        XCTAssertEqual(reportedErrors.count, 1)
        XCTAssertFalse(reportedErrors.first?.localizedDescription.isEmpty ?? true)
        XCTAssertFalse(viewModel.imported.map(\.lastPathComponent).contains { $0.hasPrefix("ha-coverage-") })
        XCTAssertFalse(viewModel.isBusy)
    }

    func testImportingNothingFromFileSharingLeavesTheScreenIdle() async throws {
        let viewModel = NotificationSoundsViewModel()

        let count = try await viewModel.importFromFileSharing()

        XCTAssertGreaterThanOrEqual(count, 0)
        XCTAssertFalse(viewModel.isBusy)
    }

    func testSoundCategoriesHaveTitles() {
        XCTAssertEqual(NotificationSoundsView.SoundCategory.allCases.count, 3)
        for category in NotificationSoundsView.SoundCategory.allCases {
            XCTAssertFalse(category.title.isEmpty)
            XCTAssertEqual(category.id, category.rawValue)
        }
    }
}
