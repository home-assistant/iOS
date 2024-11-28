import Foundation
import Shared
import SwiftUI

public enum WidgetBasicSizeStyle {
    case single
    case expanded
    case condensed
    /// Minimum size possible for widget, removing padding and borders as well
    case compressed
    case regular

    var textFont: Font {
        switch self {
        case .single, .expanded:
            return .subheadline
        case .condensed, .regular, .compressed:
            return .footnote
        }
    }

    var subtextFont: Font {
        switch self {
        case .single, .expanded:
            return .footnote
        case .regular, .condensed, .compressed:
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
        case .condensed, .compressed:
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
        case .regular, .condensed, .compressed:
            return .init(width: 38, height: 38)
        }
    }
}
