import Foundation

/// The one interactive send `WatchAssistAudioStreamer` needs, so tests can stand in for
/// WatchConnectivity. `errorHandler` fires at most once, on delivery failure or reply timeout.
public protocol WatchAssistAudioStreamSending: AnyObject {
    func sendAssistAudioStreamMessage(
        _ message: HAWatchConnectivity.InteractiveImmediateMessage,
        errorHandler: @escaping (Error) -> Void
    )
}

extension WatchConnectivityManager: WatchAssistAudioStreamSending {
    public func sendAssistAudioStreamMessage(
        _ message: HAWatchConnectivity.InteractiveImmediateMessage,
        errorHandler: @escaping (Error) -> Void
    ) {
        // A recording in progress is the user talking: nothing queued behind it should go first.
        send(message, priority: .userAction, errorHandler: errorHandler)
    }
}
