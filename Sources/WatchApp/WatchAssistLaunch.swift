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
    static func request(serverId: String, pipelineId: String) {
        pendingPresentation = .session(serverId: serverId, pipelineId: pipelineId, prompt: nil)
        NotificationCenter.default.post(name: launchNotification, object: nil)
    }
}
