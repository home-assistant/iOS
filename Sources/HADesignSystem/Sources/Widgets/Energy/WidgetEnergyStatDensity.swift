#if !os(watchOS)
import CoreGraphics
import SwiftUI

/// How tightly a row or column of energy figures is packed.
///
/// A dashboard configured for grid, solar, a battery and gas puts four figures where the widget
/// used to draw two, and a widget can't scroll or wrap the way the dashboard's cards do. So the
/// type sizes step down as figures are added rather than every figure being drawn at one size and
/// left to `minimumScaleFactor` — scaling shrinks the number but not the caption under it, which is
/// how a crowded card ends up with a headline figure smaller than its own label.
public enum WidgetEnergyStatDensity: Sendable {
    /// A single figure with a whole small card to itself.
    case hero
    /// Two figures stacked on a small card.
    case large
    /// Two figures side by side on a wide card.
    case regular
    /// Three figures.
    case compact
    /// Four or more figures.
    case dense

    /// The density for a small card, which stacks its figures and so has height to trade.
    public static func stacked(count: Int) -> Self {
        switch count {
        case ...1: .hero
        case 2: .large
        case 3: .compact
        default: .dense
        }
    }

    /// The density for a wide card's single row of figures, which trades width instead.
    public static func inRow(count: Int) -> Self {
        switch count {
        case ...2: .regular
        case 3: .compact
        default: .dense
        }
    }

    /// Whether there are more figures than a layout built for two can place as it stands. Past two,
    /// a small card's column runs off the bottom and a wide card's row has no width left over for
    /// the cost beside it, so each layout rearranges: the small card into two columns, the wide one
    /// by lifting the cost onto a line of its own.
    public var isCrowded: Bool {
        self == .compact || self == .dense
    }

    public var valueSize: CGFloat {
        switch self {
        case .hero: 34
        case .large: 22
        case .regular: 20
        case .compact: 16
        case .dense: 14
        }
    }

    public var unitSize: CGFloat {
        switch self {
        case .hero, .large, .regular: 12
        case .compact: 10
        case .dense: 9
        }
    }

    public var labelSize: CGFloat {
        switch self {
        case .hero, .large, .regular: 11
        case .compact: 10
        case .dense: 9
        }
    }

    public var iconSize: CGFloat {
        switch self {
        case .hero, .large, .regular: 12
        case .compact: 11
        case .dense: 10
        }
    }

    /// The gap between figures. Denser layouts give the space back to the figures themselves.
    public var spacing: CGFloat {
        switch self {
        case .hero, .large, .regular: DesignSystem.Spaces.one
        case .compact: DesignSystem.Spaces.half
        case .dense: DesignSystem.Spaces.micro
        }
    }

    public var valueFont: Font {
        .system(size: valueSize, weight: .bold, design: .rounded)
    }
}
#endif
