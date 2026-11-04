#if !os(watchOS)
import Foundation
import SFSafeSymbols

/// Which way an energy figure is flowing, as an arrow beside it.
public enum WidgetEnergyDirection: Sendable {
    case up, down, none

    public var symbol: SFSymbol? {
        switch self {
        case .up: .arrowUp
        case .down: .arrowDown
        case .none: nil
        }
    }

    /// Text-only arrow, for the inline accessory where the system allows a single leading symbol
    /// and the direction has to travel inside the text itself.
    public var arrowCharacter: String {
        switch self {
        case .up: "\u{2191}"
        case .down: "\u{2193}"
        case .none: ""
        }
    }
}
#endif
