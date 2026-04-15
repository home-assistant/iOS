import SwiftUI
import UIKit

public extension MagicItem {
    static var defaultAssistIconColorHex: String {
        Color.haPrimary.hex() ?? UIColor(Color.haPrimary).hexString()
    }
}
