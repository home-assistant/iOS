import Foundation
import Shared
import SwiftUI

enum WidgetBasicSizeStyle {
    case single
    case expanded
    case condensed
    case regular

    var textFont: Font {
        .system(size: 12)
    }

    var subtextFont: Font {
        .system(size: 12)
    }

    var iconFont: Font {
        .custom(MaterialDesignIcons.familyName, size: 20)
    }
}
