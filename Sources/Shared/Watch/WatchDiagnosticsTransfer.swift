import Foundation

/// Moves the watch's diagnostics archive to the paired iPhone over Watch Connectivity, because the
/// watchOS share sheet cannot reliably hand over an arbitrary file. The watch pushes the zip as a
/// blob (`transferFile`, delivery does not require reachability); the iPhone saves it into its
/// logs directory so the app's regular "Export Log Files" ships it alongside the iPhone's own logs.
public enum WatchDiagnosticsTransfer {
    public static let blobIdentifier = "watchDiagnosticsArchive"
    private static let fileNameMetadataKey = "fileName"
    /// Marker in the archive's file name, used to find and replace the previous archive on the
    /// iPhone so repeated transfers don't grow the logs directory.
    private static let fileNameMarker = ".watch-logs"

    #if os(watchOS)
    /// Queues the archive for transfer. The completion fires once the iPhone has received the file
    /// (or the transfer permanently failed) — that can be well after the call when the iPhone
    /// isn't reachable, but the transfer keeps going even if the watch app is backgrounded.
    public static func send(archiveURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let content: Data
        do {
            content = try Data(contentsOf: archiveURL)
        } catch {
            completion(.failure(error))
            return
        }
        Communicator.shared.transfer(
            HAWatchConnectivity.Blob(
                identifier: blobIdentifier,
                content: content,
                metadata: [fileNameMetadataKey: archiveURL.lastPathComponent]
            ),
            completion: completion
        )
    }
    #else
    /// Saves a received archive into the logs directory (replacing any previous one) and returns
    /// the saved location.
    public static func save(_ blob: HAWatchConnectivity.Blob) throws -> URL {
        let fileManager = FileManager.default
        let fileName = (blob.metadata?[fileNameMetadataKey] as? String) ?? "received\(fileNameMarker).zip"
        let directory = AppConstants.LogsDirectory
        if let existing = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for url in existing where url.lastPathComponent.contains(fileNameMarker) {
                try? fileManager.removeItem(at: url)
            }
        }
        let destination = directory.appendingPathComponent(fileName, isDirectory: false)
        try blob.content.write(to: destination)
        return destination
    }
    #endif
}
