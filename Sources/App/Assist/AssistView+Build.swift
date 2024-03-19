import Foundation
import Shared

extension AssistView {
    static func build(
        server: Server,
        preferredPipelineId: String = ""
    ) -> AssistView {
        let viewModel = AssistViewModel(
            preferredPipelineId: preferredPipelineId,
            audioRecorder: AudioRecorder(),
            audioPlayer: AudioPlayer(),
            assistService: AssistService(server: server)
        )
        return .init(viewModel: viewModel)
    }
}
