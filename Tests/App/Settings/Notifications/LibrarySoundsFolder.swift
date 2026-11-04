import Foundation
@testable import HomeAssistant

/// The app's `Library/Sounds` folder is real app data: importing overwrites the sounds there that share a
/// name, and cleaning up afterwards would delete sounds that were there before the test. `preserved` copies
/// the folder aside before `body` runs and puts it back exactly as it was once `body` returns or throws.
@MainActor
enum LibrarySoundsFolder {
    static func preserved<T>(_ body: () async throws -> T) async throws -> T {
        let fileManager = FileManager.default
        let folder = try NotificationSoundsViewModel().librarySoundsURL()
        let backup = fileManager.temporaryDirectory
            .appendingPathComponent("LibrarySounds-\(UUID().uuidString)", isDirectory: true)
        try fileManager.copyItem(at: folder, to: backup)
        defer {
            try? fileManager.removeItem(at: folder)
            try? fileManager.moveItem(at: backup, to: folder)
        }
        return try await body()
    }
}
