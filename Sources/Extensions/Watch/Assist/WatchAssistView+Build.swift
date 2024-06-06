import Foundation
import Shared

extension WatchAssistView {
    static func build() -> WatchAssistView {
        let viewModel = WatchAssistViewModel(
            audioRecorder: WatchAudioRecorder()
        )
        return WatchAssistView(viewModel: viewModel, assistService: WatchAssistService())
    }
}
