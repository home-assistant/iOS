import Foundation
import Shared

extension WatchAssistView {
    static func build(serverId: String, pipelineId: String) -> WatchAssistView {
        // The whole view-model expression is passed as an autoclosure so it only runs when SwiftUI
        // first creates the view's @StateObject storage. This builder is called from a
        // `fullScreenCover` content closure, which re-evaluates on every parent re-render (config
        // syncs re-render the home screen mid-session) — building the view model eagerly here
        // created a ghost instance each time, and each ghost registered itself as a communicator
        // observer from its init.
        WatchAssistView(viewModel: WatchAssistViewModel(
            assistService: WatchAssistService(serverId: serverId, pipelineId: pipelineId),
            audioRecorder: WatchAudioRecorder(),
            audioPlayer: AudioPlayer(),
            immediateCommunicatorService: .shared
        ))
    }
}
