import Foundation
import Shared

extension AssistView {
    static func build(
        server: Server,
        preferredPipelineId: String = "",
        autoStartRecording: Bool = false,
        showCloseButton: Bool = true
    ) -> AssistView {
        let speechTranscriber: SpeechTranscriberProtocol
        if #available(iOS 17, *) {
            speechTranscriber = SpeechTranscriberAdapter()
        } else {
            speechTranscriber = NoOpSpeechTranscriber()
        }

        let viewModel = AssistViewModel(
            server: server,
            preferredPipelineId: preferredPipelineId,
            audioRecorder: AudioRecorder(),
            audioPlayer: AudioPlayer(),
            assistService: AssistService(server: server),
            speechTranscriber: speechTranscriber,
            autoStartRecording: autoStartRecording
        )
        return .init(viewModel: viewModel, showCloseButton: showCloseButton)
    }
}
