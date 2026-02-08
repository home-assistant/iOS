import Foundation
import Shared
import WebKit

@MainActor
final class DownloadManagerViewModel: NSObject, ObservableObject {
    @Published var fileName: String = ""
    @Published var finished: Bool = false
    @Published var failed: Bool = false
    @Published var errorMessage: String = ""
    @Published var progress: String = ""
    @Published var lastURLCreated: URL?

    private var progressObservation: NSKeyValueObservation?
    private var lastDownload: WKDownload?

    func deleteFile() {
        if let url = lastURLCreated {
            // Guarantee to delete file before leaving screen
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Current.Log.error("Failed to remove file before leaving download manager at \(url), error: \(error)")
            }
        }
    }

    func cancelDownload() {
        progressObservation?.invalidate()
        lastDownload?.cancel()
    }

    private func bytesToMBString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

extension DownloadManagerViewModel: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String
    ) async -> URL? {
        lastDownload = download
        let name = suggestedFilename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "Unknown"
        fileName = name
        if let url = URL(string: name, relativeTo: AppConstants.DownloadsDirectory) {
            lastURLCreated = url
            // Guarantee file does not exist, otherwise download will fail
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Current.Log.error("Failed to remove file for download manager at \(url), error: \(error)")
            }
            progressObservation?.invalidate()
            progressObservation = download.progress.observe(\.completedUnitCount) { [weak self] progress, _ in
                guard let self else { return }
                self.progress = bytesToMBString(progress.completedUnitCount)
            }
            return url
        } else {
            return nil
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        finished = true
    }

    func download(_ download: WKDownload, didFailWithError error: any Error, resumeData: Data?) {
        errorMessage = L10n.DownloadManager.Failed.title(error.localizedDescription)
        failed = true
    }
}
