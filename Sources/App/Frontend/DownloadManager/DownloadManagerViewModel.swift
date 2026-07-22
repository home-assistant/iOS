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
    private var backgroundTaskIdentifier: Int?

    /// Re-issues a `WKDownload`'s request on `BackgroundDownloadManager`'s background `URLSession` so the
    /// transfer keeps going while the app is suspended. Cookies live in the web view's store rather than
    /// the app's shared one, so they are copied onto the request for setups that authenticate with them.
    func startBackgroundDownload(request: URLRequest, server: Server, cookieStore: WKHTTPCookieStore) {
        fileName = request.url?.lastPathComponent ?? ""
        BackgroundDownloadManager.shared.delegate = self
        cookieStore.getAllCookies { cookies in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let task = BackgroundDownloadManager.shared.download(
                    Self.request(request, addingCookies: cookies),
                    for: server
                )
                self.backgroundTaskIdentifier = task.taskIdentifier
            }
        }
    }

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
        if let backgroundTaskIdentifier {
            BackgroundDownloadManager.shared.cancel(taskIdentifier: backgroundTaskIdentifier)
        }
    }

    nonisolated static func request(_ request: URLRequest, addingCookies cookies: [HTTPCookie]) -> URLRequest {
        guard let url = request.url else { return request }
        let matching = cookies.filter { cookie($0, matches: url) }
        guard !matching.isEmpty else { return request }
        return with(request) { request in
            for (header, value) in HTTPCookie.requestHeaderFields(with: matching) {
                request.setValue(value, forHTTPHeaderField: header)
            }
        }
    }

    private nonisolated static func cookie(_ cookie: HTTPCookie, matches url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let domain = cookie.domain.lowercased()
        let domainMatches: Bool
        if domain.hasPrefix(".") {
            domainMatches = host == String(domain.dropFirst()) || host.hasSuffix(domain)
        } else {
            domainMatches = host == domain
        }
        guard domainMatches else { return false }
        if cookie.isSecure, url.scheme?.lowercased() != "https" { return false }
        return pathMatches(requestPath: url.path, cookiePath: cookie.path)
    }

    /// RFC 6265 §5.1.4 path matching: a bare prefix isn't enough — `/admin` must not match `/administrator`.
    private nonisolated static func pathMatches(requestPath: String, cookiePath: String) -> Bool {
        let requestPath = requestPath.isEmpty ? "/" : requestPath
        if cookiePath == requestPath { return true }
        guard requestPath.hasPrefix(cookiePath) else { return false }
        if cookiePath.hasSuffix("/") { return true }
        return requestPath[requestPath.index(requestPath.startIndex, offsetBy: cookiePath.count)] == "/"
    }

    private func bytesToMBString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

extension DownloadManagerViewModel: BackgroundDownloadManagerDelegate {
    nonisolated func backgroundDownload(
        taskIdentifier: Int,
        didWriteBytes totalBytesWritten: Int64,
        expectedTotalBytes: Int64,
        suggestedFilename: String?
    ) {
        Task { @MainActor [weak self] in
            guard let self, taskIdentifier == self.backgroundTaskIdentifier else { return }
            if let suggestedFilename { self.fileName = suggestedFilename }
            self.progress = bytesToMBString(totalBytesWritten)
        }
    }

    nonisolated func backgroundDownload(taskIdentifier: Int, didFinishDownloadingTo url: URL) {
        Task { @MainActor [weak self] in
            guard let self, taskIdentifier == self.backgroundTaskIdentifier else { return }
            self.fileName = url.lastPathComponent
            self.lastURLCreated = url
            self.finished = true
        }
    }

    nonisolated func backgroundDownload(taskIdentifier: Int, didFailWith error: Error) {
        Task { @MainActor [weak self] in
            guard let self, taskIdentifier == self.backgroundTaskIdentifier else { return }
            self.errorMessage = L10n.DownloadManager.Failed.title(error.localizedDescription)
            self.failed = true
        }
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
                let completedUnitCount = progress.completedUnitCount
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.progress = bytesToMBString(completedUnitCount)
                }
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
