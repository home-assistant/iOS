import Foundation
import Shared

/// Which tile layout a widget draws: an action the user taps, or a reading.
enum WidgetType: String {
    case button
    case sensor
    case custom

    /// The design system's own tile kinds. `custom` widgets are made of action tiles too — the
    /// distinction only matters to the intents behind them.
    var tileKind: WidgetTileKind {
        switch self {
        case .button, .custom: .button
        case .sensor: .sensor
        }
    }
}
