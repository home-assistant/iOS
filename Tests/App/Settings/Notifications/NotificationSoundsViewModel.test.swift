import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Shared state: these tests write sound files into the app container's `Library/Sounds` and
/// `Documents` folders, which other tests (and the sounds screen) read.
@Suite(.sharedState)
@MainActor
struct NotificationSoundsViewModelTests {
    @Test func loadsTheBundledSoundsSortedByName() throws {
        let viewModel = NotificationSoundsViewModel()
        viewModel.loadSounds()

        #expect(!viewModel.bundled.isEmpty)
        #expect(viewModel.bundled.allSatisfy { $0.pathExtension == "wav" })
        let names = viewModel.bundled.map(\.lastPathComponent)
        #expect(names == names.sorted())
        #expect(viewModel.imported.allSatisfy { $0.lastPathComponent.hasSuffix(".wav") })
        #expect(viewModel.system.allSatisfy { $0.lastPathComponent.hasSuffix(".caf") })
    }

    @Test func librarySoundsFolderIsCreatedUnderLibrary() throws {
        let url = try NotificationSoundsViewModel().librarySoundsURL()
        #expect(url.lastPathComponent == "Sounds")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func playingAMissingFileReportsTheError() {
        let viewModel = NotificationSoundsViewModel()
        var reported: Error?
        viewModel.play(url: URL(fileURLWithPath: "/nonexistent/sound.wav")) { reported = $0 }
        #expect(reported != nil)
        viewModel.stopPlayback()
    }

    @Test func playingABundledSoundSucceeds() throws {
        let viewModel = NotificationSoundsViewModel()
        viewModel.loadSounds()
        let sound = try #require(viewModel.bundled.first)
        var reported: Error?
        viewModel.play(url: sound) { reported = $0 }
        #expect(reported == nil)
        viewModel.stopPlayback()
    }

    @Test func deletingAMissingSoundThrowsADeleteError() throws {
        let viewModel = NotificationSoundsViewModel()
        let error = #expect(throws: (any Error).self) {
            try viewModel.deleteSound(URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).wav"))
        }
        #expect(error?.localizedDescription.isEmpty == false)
    }

    @Test func deletingASoundRemovesItFromDiskAndBothLists() throws {
        let viewModel = NotificationSoundsViewModel()
        let folder = try viewModel.librarySoundsURL()
        let imported = folder.appendingPathComponent("test-\(UUID().uuidString).wav")
        let system = folder.appendingPathComponent("test-\(UUID().uuidString).caf")
        try Data("x".utf8).write(to: imported)
        try Data("x".utf8).write(to: system)

        viewModel.loadSounds()
        #expect(viewModel.imported.contains(imported))
        #expect(viewModel.system.contains(system))

        try viewModel.deleteSound(imported)
        try viewModel.deleteSound(system)
        #expect(!viewModel.imported.contains(imported))
        #expect(!viewModel.system.contains(system))
        #expect(!FileManager.default.fileExists(atPath: imported.path))
    }

    /// A sound dropped into Documents (iTunes file sharing) is copied into `Library/Sounds`; doing
    /// it twice replaces the earlier copy instead of failing.
    /// Every sound in Documents is copied over the same-named ones in `Library/Sounds`, so the folder is restored
    /// afterwards.
    @Test func importsSoundsFromFileSharingAndReplacesExistingCopies() async throws {
        try await LibrarySoundsFolder.preserved {
            let viewModel = NotificationSoundsViewModel()
            viewModel.loadSounds()
            let bundled = try #require(viewModel.bundled.first)
            let documents = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let name = "test-sharing-\(UUID().uuidString).wav"
            let shared = documents.appendingPathComponent(name)
            let copied = try viewModel.librarySoundsURL().appendingPathComponent(name)
            try FileManager.default.copyItem(at: bundled, to: shared)
            defer { try? FileManager.default.removeItem(at: shared) }

            let first = try await viewModel.importFromFileSharing()
            #expect(first >= 1)
            #expect(viewModel.imported.contains(copied))
            #expect(!viewModel.isBusy)

            let second = try await viewModel.importFromFileSharing()
            #expect(second >= 1)
            #expect(viewModel.imported.filter { $0 == copied }.count == 1)
        }
    }

    /// The imported system sounds are undone by restoring the sounds folder as it was.
    @Test func importsTheSystemSoundsAndCleansUp() async throws {
        try await LibrarySoundsFolder.preserved {
            let viewModel = NotificationSoundsViewModel()
            let count = try await viewModel.importSystemSounds()
            #expect(count == viewModel.system.count)
            #expect(!viewModel.isBusy)
        }
    }

    @Test func convertsAPickedFileIntoTheSoundsFolder() async throws {
        let viewModel = NotificationSoundsViewModel()
        viewModel.loadSounds()
        let bundled = try #require(viewModel.bundled.first)
        let picked = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-picked-\(UUID().uuidString).wav")
        try FileManager.default.copyItem(at: bundled, to: picked)
        let converted = try viewModel.librarySoundsURL().appendingPathComponent(picked.lastPathComponent)
        defer {
            try? FileManager.default.removeItem(at: picked)
            try? FileManager.default.removeItem(at: converted)
        }

        var errors: [Error] = []
        await viewModel.importPickedFiles([picked]) { errors.append($0) }
        #expect(errors.isEmpty)
        #expect(viewModel.imported.contains(converted))
        #expect(!viewModel.isBusy)
    }

    @Test func reportsAPickedFileThatCannotBeConverted() async throws {
        let viewModel = NotificationSoundsViewModel()
        let picked = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-broken-\(UUID().uuidString).mp3")
        try Data("not audio".utf8).write(to: picked)
        let converted = try viewModel.librarySoundsURL()
            .appendingPathComponent(picked.deletingPathExtension().lastPathComponent + ".wav")
        defer {
            try? FileManager.default.removeItem(at: picked)
            try? FileManager.default.removeItem(at: converted)
        }

        var errors: [Error] = []
        await viewModel.importPickedFiles([picked]) { errors.append($0) }
        #expect(errors.count == 1)
        #expect(errors.first?.localizedDescription.isEmpty == false)
        #expect(!viewModel.imported.contains(converted))
    }
}
