import Foundation

/// Receives `BackgroundDownloadManager` events, on the main queue. Events carry the download task's
/// identifier so an observer can ignore tasks it does not own.
protocol BackgroundDownloadManagerDelegate: AnyObject {
    func backgroundDownload(
        taskIdentifier: Int,
        didWriteBytes totalBytesWritten: Int64,
        expectedTotalBytes: Int64,
        suggestedFilename: String?
    )
    func backgroundDownload(taskIdentifier: Int, didFinishDownloadingTo url: URL)
    func backgroundDownload(taskIdentifier: Int, didFailWith error: Error)
}
