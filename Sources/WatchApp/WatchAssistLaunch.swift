import Foundation
import Shared

/// Bridges the Assist App Intents to the watch's full-screen Assist cover.
enum WatchAssistLaunch {
    static let launchNotification: Notification.Name = .init("watch-assist-launch")

    /// Set when the intent runs before the UI is ready to present Assist. `WatchHomeView` consumes
    /// this on appear so a cold launch still opens the session (the launch notification would
    /// otherwise fire before the view subscribes to it).
    static var pendingPresentation: WatchAssistPresentation?

    /// Asks the app to run `pipelineId` on `serverId`, whether or not the UI is already on screen.
    /// An empty `pipelineId` means the server's preferred pipeline.
    static func request(serverId: String, pipelineId: String) {
        request(.session(serverId: serverId, pipelineId: pipelineId, prompt: nil))
    }

    /// Asks the app to open the Assist configured for the watch (the same server and pipeline the
    /// complication and the home screen button use), falling back to the first server's preferred
    /// pipeline when nothing is configured.
    static func requestConfigured() {
        request(configuredPresentation(
            assist: ((try? WatchConfig.config()) ?? nil)?.assist,
            servers: Current.servers.all
        ))
    }

    static func configuredPresentation(assist: WatchConfig.Assist?, servers: [Server]) -> WatchAssistPresentation {
        let configuredServer = servers.first { $0.identifier.rawValue == assist?.serverId }
        guard let server = configuredServer ?? servers.first else { return .unconfigured }
        let pipelineId = configuredServer == nil ? "" : (assist?.pipelineId ?? "")
        return .session(serverId: server.identifier.rawValue, pipelineId: pipelineId, prompt: nil)
    }

    /// App Intents can run `perform()` off the main thread, and `NotificationCenter` delivers
    /// synchronously on the posting thread — which would land `WatchHomeView`'s SwiftUI state
    /// mutation off-main. Hop first so both the latch and the delivery happen on the main thread.
    private static func request(_ presentation: WatchAssistPresentation) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { request(presentation) }
            return
        }
        pendingPresentation = presentation
        NotificationCenter.default.post(name: launchNotification, object: nil)
    }
}
