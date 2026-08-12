import Foundation

/// Bridges the "Assist in app" App Intent to the watch's full-screen Assist cover.
enum WatchAssistLaunch {
    static let launchNotification: Notification.Name = .init("watch-assist-launch")

    /// Set when the intent runs before the UI is ready to present Assist. `WatchHomeView` consumes
    /// this on appear so a cold launch still opens the session (the launch notification would
    /// otherwise fire before the view subscribes to it).
    static var pendingPresentation: WatchAssistPresentation?

    /// Asks the app to run `pipelineId` on `serverId`, whether or not the UI is already on screen.
    /// An empty `pipelineId` means the server's preferred pipeline.
    ///
    /// App Intents can run `perform()` off the main thread, and `NotificationCenter` delivers
    /// synchronously on the posting thread — which would land `WatchHomeView`'s SwiftUI state
    /// mutation off-main. Hop first so both the latch and the delivery happen on the main thread.
    static func request(serverId: String, pipelineId: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { request(serverId: serverId, pipelineId: pipelineId) }
            return
        }
        pendingPresentation = .session(serverId: serverId, pipelineId: pipelineId, prompt: nil)
        NotificationCenter.default.post(name: launchNotification, object: nil)
    }
}
