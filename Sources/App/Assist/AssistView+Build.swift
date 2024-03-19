import Foundation
import Shared

extension AssistView {
    static func build(
        server: Server,
        preferredPipelineId: String = ""
    ) -> AssistView {
        let viewModel = AssistViewModel(
            server: server,
            preferredPipelineId: preferredPipelineId,
            audioRecorder: AudioRecorder(),
            audioPlayer: AudioPlayer()
        )
        return .init(viewModel: viewModel)
    }
}
