import Foundation
import WatchKit

struct AssistRowControllerData {
    let content: String
    let type: ContentType

    enum ContentType {
        case input, output
    }
}

final class AssistRowController: NSObject {
    @IBOutlet private var titleLabel: WKInterfaceLabel!
    @IBOutlet private var rowGroup: WKInterfaceGroup!

    static var rowType: String {
        "AssistRowController"
    }

    func setContent(data: AssistRowControllerData) {
        titleLabel.setText(data.content)

        switch data.type {
        case .input:
            rowGroup.setHorizontalAlignment(.right)
        case .output:
            rowGroup.setBackgroundColor(.gray)
            rowGroup.setHorizontalAlignment(.left)
        }
    }
}
