import Foundation
import Shared

extension AssistView {
    static func build(
        server: Server,
        preferredPipelineId: String = "",
        autoStartRecording: Bool = false
    ) -> AssistView {
        let viewModel = AssistViewModel(
            server: server,
            preferredPipelineId: preferredPipelineId,
            audioRecorder: AudioRecorder(),
            audioPlayer: AudioPlayer(),
            assistService: AssistService(server: server),
            autoStartRecording: autoStartRecording
        )
        return .init(viewModel: viewModel)
    }
}
