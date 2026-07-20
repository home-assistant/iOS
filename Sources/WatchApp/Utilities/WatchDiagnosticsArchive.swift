import Foundation
import Shared

/// Zip of the watch's diagnostic files — client events, the GRDB database and the rotating
/// `Current.Log` files — shared from the client events screen. The archive is built eagerly on a
/// dedicated thread before the `ShareLink` is offered: it was previously built lazily inside a
/// `Transferable` `FileRepresentation` exporting closure, which is async and therefore runs on the
/// Swift-concurrency pool — starved on watch hardware, so the share sheet hung forever after
/// picking a target. ZIPFoundation isn't linked on watchOS, so zipping uses `NSFileCoordinator`'s
/// `.forUploading` conversion instead.
enum WatchDiagnosticsArchive {
    private enum ArchiveError: Error {
        case zipConversionFailed
    }

    static func makeArchive() throws -> URL {
        let fileManager = FileManager.default
        let stagingURL = fileManager.temporaryDirectory
            .appendingPathComponent("watch-diagnostics-\(UUID().uuidString)", isDirectory: true)
        // The folder handed to the coordinator names the zip's top-level folder.
        let contentsURL = stagingURL.appendingPathComponent("HomeAssistant-Watch-Logs", isDirectory: true)
        try fileManager.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingURL) }

        // Each file is best-effort so one missing file doesn't block the export.
        var sources: [URL] = [
            AppConstants.clientEventsFile,
            AppConstants.appGRDBFile,
        ]
        // In WAL journal mode the newest writes live in the sidecars, so a copy of just the main
        // SQLite file can be stale or unreadable without them.
        for suffix in ["-wal", "-shm"] {
            let sidecarURL = URL(fileURLWithPath: AppConstants.appGRDBFile.path + suffix)
            if fileManager.fileExists(atPath: sidecarURL.path) {
                sources.append(sidecarURL)
            }
        }
        do {
            try sources.append(contentsOf: fileManager.contentsOfDirectory(
                at: AppConstants.LogsDirectory,
                includingPropertiesForKeys: nil
            ))
        } catch {
            Current.Log.info("No log files added to watch diagnostics export: \(error.localizedDescription)")
        }
        for source in sources {
            do {
                try fileManager.copyItem(
                    at: source,
                    to: contentsURL.appendingPathComponent(source.lastPathComponent)
                )
            } catch {
                Current.Log.info(
                    "Skipping \(source.lastPathComponent) in watch diagnostics export: \(error.localizedDescription)"
                )
            }
        }

        let formatter = with(DateFormatter()) {
            $0.dateFormat = "yyyy-MM-dd'_'HH'.'mm'.'ssZ'.watch-logs.zip'"
            $0.locale = Locale(identifier: "en_US_POSIX")
        }
        let fileName = formatter.string(from: Current.date())
        // Each export gets its own directory so concurrent shares can't clobber each other's archive
        // while the share sheet is still reading it.
        let exportURL = fileManager.temporaryDirectory
            .appendingPathComponent("watch-diagnostics-export-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        let archiveURL = exportURL.appendingPathComponent(fileName, isDirectory: false)

        var result: Result<URL, Error> = .failure(ArchiveError.zipConversionFailed)
        var coordinatorError: NSError?
        // `.forUploading` makes the coordinator hand back a zipped copy of the directory; that copy
        // only lives for the duration of the accessor, so move it out before returning.
        NSFileCoordinator().coordinate(
            readingItemAt: contentsURL,
            options: .forUploading,
            error: &coordinatorError
        ) { zippedURL in
            do {
                try fileManager.moveItem(at: zippedURL, to: archiveURL)
                result = .success(archiveURL)
            } catch {
                result = .failure(error)
            }
        }
        if let coordinatorError {
            Current.Log.error("Failed to zip watch diagnostics: \(coordinatorError.localizedDescription)")
            throw coordinatorError
        }
        return try result.get()
    }
}
