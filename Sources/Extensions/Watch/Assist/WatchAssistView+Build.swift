import Foundation
import Shared

extension WatchAssistView {
    static func build() -> WatchAssistView {
        let viewModel = WatchAssistViewModel(
            audioRecorder: WatchAudioRecorder(),
            assistService: WatchAssistService()
        )
        return WatchAssistView(viewModel: viewModel)
    }
}
