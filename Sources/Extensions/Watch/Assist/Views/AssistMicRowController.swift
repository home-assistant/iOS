import Foundation
import WatchKit

enum AssistMicRowControllerStates {
    case standard, loading, inProgress
}

@available(watchOS 6, *)
final class AssistMicRowController: NSObject {
    @IBOutlet private var button: WKInterfaceButton!
    var action: (() -> Void)?

    static var rowType: String {
        "AssistMicRowController"
    }

    @IBAction func didTapMic() {
        action?()
    }

    func updateState(_ newState: AssistMicRowControllerStates) {
        var newImageName = ""

        switch newState {
        case .standard:
            newImageName = "mic.circle.fill"
            button.setEnabled(true)
        case .loading:
            newImageName = "ellipsis.circle.fill"
            button.setEnabled(false)
        case .inProgress:
            newImageName = "stop.circle"
            button.setEnabled(true)
        }

        button.setBackgroundImage(UIImage(systemName: newImageName))
    }
}
