import Foundation
import Shared
import SwiftUI

enum WidgetBasicSizeStyle {
    case single
    case expanded
    case condensed
    case regular

    var textFont: Font {
        switch self {
        case .single, .expanded:
            return .subheadline
        case .condensed, .regular:
            return .footnote
        }
    }

    var subtextFont: Font {
        switch self {
        case .single, .expanded:
            return .footnote
        case .regular, .condensed:
            return .system(size: 12)
        }
    }

    var iconFont: Font {
        let size: CGFloat

        switch self {
        case .single, .expanded:
            size = 32
        case .regular:
            size = 20
        case .condensed:
            size = 14
        }

        return .custom(MaterialDesignIcons.familyName, size: size)
    }

    /// Icon circle background size
    var iconCircleSize: CGSize {
        switch self {
        case .single, .expanded:
            return .init(width: 48, height: 48)
        case .regular:
            return .init(width: 38, height: 38)
        case .condensed:
            return .init(width: 38, height: 38)
        }
    }
}
