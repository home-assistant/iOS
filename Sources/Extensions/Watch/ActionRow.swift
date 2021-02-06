import EMTLoadingIndicator
import Foundation
import Shared
import WatchKit

class ActionRowType: NSObject {
    @IBOutlet var group: WKInterfaceGroup!
    @IBOutlet var label: WKInterfaceLabel!
    @IBOutlet var image: WKInterfaceImage!

    var indicator: EMTLoadingIndicator?
    var icon = MaterialDesignIcons.fileQuestionIcon
}
