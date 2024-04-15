import Foundation

extension WatchAssistView {
    static func build() -> WatchAssistView<WatchAssistViewModel> {
        WatchAssistView<WatchAssistViewModel>(viewModel: WatchAssistViewModel())
    }
}
