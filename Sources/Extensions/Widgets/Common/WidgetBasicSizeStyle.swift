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
        case .single:
            size = 32
        case .expanded:
            size = 28
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
        case .single:
            return .init(width: 48, height: 48)
        case .expanded:
            return .init(width: 42, height: 42)
        case .regular, .condensed:
            return .init(width: 38, height: 38)
        }
    }
}
