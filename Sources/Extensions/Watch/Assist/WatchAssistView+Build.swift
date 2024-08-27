import Foundation
import Shared

extension WatchAssistView {
    static func build(serverId: String, pipelineId: String) -> WatchAssistView {
        let viewModel = WatchAssistViewModel(
            assistService: WatchAssistService(serverId: serverId, pipelineId: pipelineId),
            audioRecorder: WatchAudioRecorder(),
            audioPlayer: AudioPlayer(),
            immediateCommunicatorService: .shared
        )
        return WatchAssistView(viewModel: viewModel)
    }
}
