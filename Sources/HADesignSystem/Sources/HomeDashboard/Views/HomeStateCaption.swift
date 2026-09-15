#if !os(watchOS)
import Foundation

/// The line under a tile's name: the state, with its unit when it has one.
///
/// The package cannot translate a state — `"heat"` reads as "Heating" only with the app's
/// translations — so it shows the raw one, capitalised. The app hands in a presenter that does it
/// properly.
public enum HomeStateCaption {
    public static func caption(for state: HomeEntityState) -> String? {
        if state.isUnavailable {
            return state.state.capitalized
        }
        if let unit = state.attributes.unitOfMeasurement, !unit.isEmpty {
            return "\(state.state) \(unit)"
        }
        return state.state.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
#endif
