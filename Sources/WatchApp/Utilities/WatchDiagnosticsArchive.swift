import CoreTransferable
import Foundation
import Shared
import UniformTypeIdentifiers

/// Zip of the watch's diagnostic files — client events, the GRDB database and the rotating
/// `Current.Log` files — shared from the client events screen. The archive is built lazily when the
/// share actually starts. ZIPFoundation isn't linked on watchOS, so zipping uses
/// `NSFileCoordinator`'s `.forUploading` conversion instead.
struct WatchDiagnosticsArchive: Transferable {
    private enum ArchiveError: Error {
        case zipConversionFailed
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .zip) { _ in
            try SentTransferredFile(makeArchive())
        }
    }

    private static func makeArchive() throws -> URL {
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
        let archiveURL = fileManager.temporaryDirectory.appendingPathComponent(fileName, isDirectory: false)
        try? fileManager.removeItem(at: archiveURL)

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
