#if !os(watchOS)
import Foundation
@testable import Shared
import Testing

@Suite(.serialized)
struct WatchDiagnosticsTransferTests {
    @Test func savesTheArchiveUnderItsTransferredName() throws {
        let fileName = "WatchDiagnosticsTransferTests-\(UUID().uuidString).watch-logs.zip"
        let blob = HAWatchConnectivity.Blob(
            identifier: WatchDiagnosticsTransfer.blobIdentifier,
            content: Data("archive".utf8),
            metadata: ["fileName": fileName]
        )

        let saved = try WatchDiagnosticsTransfer.save(blob)
        defer { try? FileManager.default.removeItem(at: saved) }

        #expect(saved.lastPathComponent == fileName)
        #expect(saved.deletingLastPathComponent().standardizedFileURL == AppConstants.LogsDirectory.standardizedFileURL)
        let stored1 = try Data(contentsOf: saved)
        #expect(stored1 == Data("archive".utf8))
    }

    @Test func aNewArchiveReplacesThePreviousOne() throws {
        let first = try WatchDiagnosticsTransfer.save(HAWatchConnectivity.Blob(
            identifier: WatchDiagnosticsTransfer.blobIdentifier,
            content: Data("first".utf8),
            metadata: ["fileName": "WatchDiagnosticsTransferTests-first.watch-logs.zip"]
        ))
        defer { try? FileManager.default.removeItem(at: first) }

        let second = try WatchDiagnosticsTransfer.save(HAWatchConnectivity.Blob(
            identifier: WatchDiagnosticsTransfer.blobIdentifier,
            content: Data("second".utf8)
        ))
        defer { try? FileManager.default.removeItem(at: second) }

        #expect(second.lastPathComponent == "received.watch-logs.zip")
        #expect(FileManager.default.fileExists(atPath: first.path) == false)
        let stored2 = try Data(contentsOf: second)
        #expect(stored2 == Data("second".utf8))
    }

    @Test func blobIdentifierIsStable() {
        #expect(WatchDiagnosticsTransfer.blobIdentifier == "watchDiagnosticsArchive")
    }
}
#endif
