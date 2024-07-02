import Foundation
import Shared

extension WatchAssistView {
    static func build() -> WatchAssistView {
        let viewModel = WatchAssistViewModel(
            audioRecorder: WatchAudioRecorder(),
            immediateCommunicatorService: .shared
        )
        return WatchAssistView(viewModel: viewModel)
    }
}
