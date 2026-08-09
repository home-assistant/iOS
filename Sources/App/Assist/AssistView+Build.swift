import Foundation
import Shared

extension AssistView {
    static func build(
        server: Server,
        preferredPipelineId: String = "",
        autoStartRecording: Bool = false,
        focusInputOnAppear: Bool = false,
        showCloseButton: Bool = true
    ) -> AssistView {
        let viewModel = AssistViewModel(
            server: server,
            preferredPipelineId: preferredPipelineId,
            audioRecorder: AudioRecorder(),
            audioPlayer: AudioPlayer(),
            assistService: AssistService(server: server),
            autoStartRecording: autoStartRecording,
            focusInputOnAppear: focusInputOnAppear
        )
        return .init(viewModel: viewModel, showCloseButton: showCloseButton)
    }
}
