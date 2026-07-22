import Foundation
import Shared

/// Runs frontend-initiated file downloads on a background `URLSession` so transfers keep going while the
/// app is suspended — and finish even if the system relaunches the app for them. See
/// https://developer.apple.com/documentation/foundation/downloading-files-in-the-background
///
/// All calls into this manager and all delegate callbacks happen on the main queue.
final class BackgroundDownloadManager: NSObject {
    static let shared = BackgroundDownloadManager()

    static var sessionIdentifier: String { AppConstants.BundleID + ".DownloadManager" }

    static func isManager(forSessionIdentifier identifier: String) -> Bool {
        identifier == sessionIdentifier
    }

    /// The presented `DownloadManagerViewModel`, when one is on screen. Downloads finished after a
    /// background relaunch have no observer; the file is still saved to `AppConstants.DownloadsDirectory`.
    weak var delegate: BackgroundDownloadManagerDelegate?

    private var backgroundEventsCompletionHandler: (() -> Void)?
    private var serverIdentifierForTask = [Int: Identifier<Server>]()

    private lazy var session = URLSession(
        configuration: with(URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)) {
            $0.sessionSendsLaunchEvents = true
            $0.isDiscretionary = false
        },
        delegate: self,
        delegateQueue: .main
    )

    @discardableResult
    func download(_ request: URLRequest, for server: Server) -> URLSessionDownloadTask {
        let task = session.downloadTask(with: request)
        serverIdentifierForTask[task.taskIdentifier] = server.identifier
        task.resume()
        return task
    }

    func cancel(taskIdentifier: Int) {
        session.getAllTasks { tasks in
            tasks.first(where: { $0.taskIdentifier == taskIdentifier })?.cancel()
        }
    }

    /// Recreates the background session after the system relaunched the app for its events, per
    /// `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
    func handleBackgroundEvents(completionHandler: @escaping () -> Void) {
        backgroundEventsCompletionHandler = completionHandler
        // Touching the session reconnects it to the background transfer daemon so queued delegate
        // events (including `urlSessionDidFinishEvents`) replay.
        _ = session
    }

    static func destinationURL(forSuggestedFilename suggestedFilename: String) -> URL? {
        let name = suggestedFilename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "Unknown"
        return URL(string: name, relativeTo: AppConstants.DownloadsDirectory)
    }

    /// Unlike `WKDownload`, a download task happily persists an HTML error page on failure statuses, so the
    /// response has to be validated before the file is kept.
    static func validationError(for response: URLResponse?) -> URLError? {
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 else { return nil }
        return URLError(.badServerResponse, userInfo: [
            NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)",
        ])
    }

    private func server(for task: URLSessionTask, host: String?) -> Server? {
        if let identifier = serverIdentifierForTask[task.taskIdentifier],
           let server = Current.servers.server(for: identifier) {
            return server
        }
        // After a background relaunch the task → server map is gone; match by host so security
        // exceptions and client certificates still apply.
        return Current.servers.all.first { server in
            server.activeURLUsingLastKnownNetworkState()?.host == host
        }
    }
}

extension BackgroundDownloadManager: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        delegate?.backgroundDownload(
            taskIdentifier: downloadTask.taskIdentifier,
            didWriteBytes: totalBytesWritten,
            expectedTotalBytes: totalBytesExpectedToWrite,
            suggestedFilename: downloadTask.response?.suggestedFilename
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        serverIdentifierForTask[downloadTask.taskIdentifier] = nil

        if let error = Self.validationError(for: downloadTask.response) {
            Current.Log.error("Background download failed with \(error) for \(downloadTask)")
            delegate?.backgroundDownload(taskIdentifier: downloadTask.taskIdentifier, didFailWith: error)
            return
        }

        let suggestedFilename = downloadTask.response?.suggestedFilename
            ?? downloadTask.originalRequest?.url?.lastPathComponent ?? "Unknown"
        guard let destination = Self.destinationURL(forSuggestedFilename: suggestedFilename) else {
            delegate?.backgroundDownload(
                taskIdentifier: downloadTask.taskIdentifier,
                didFailWith: URLError(.cannotCreateFile)
            )
            return
        }

        // The temporary file only exists until this method returns, so it has to be moved synchronously.
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            delegate?.backgroundDownload(
                taskIdentifier: downloadTask.taskIdentifier,
                didFinishDownloadingTo: destination
            )
        } catch {
            Current.Log.error("Failed to move background download to \(destination), error: \(error)")
            delegate?.backgroundDownload(taskIdentifier: downloadTask.taskIdentifier, didFailWith: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        serverIdentifierForTask[task.taskIdentifier] = nil

        guard let error, (error as? URLError)?.code != .cancelled else { return }
        Current.Log.error("Background download completed with error: \(error)")
        delegate?.backgroundDownload(taskIdentifier: task.taskIdentifier, didFailWith: error)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let server = server(for: task, host: challenge.protectionSpace.host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        let (disposition, credential) = server.info.connection.evaluate(challenge)
        completionHandler(disposition, credential)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        backgroundEventsCompletionHandler?()
        backgroundEventsCompletionHandler = nil
    }
}
