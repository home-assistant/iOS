import Foundation
import Shared

extension WatchAssistView {
    static func build() -> WatchAssistView {
        let viewModel = WatchAssistViewModel(
            audioRecorder: WatchAudioRecorder(),
            assistService: WatchAssistService(),
            immediateCommunicatorService: .shared
        )
        return WatchAssistView(viewModel: viewModel)
    }
}
