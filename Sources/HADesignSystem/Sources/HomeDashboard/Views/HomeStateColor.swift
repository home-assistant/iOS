#if !os(watchOS)
import SwiftUI

/// The colour an entity's icon takes, resolved against the frontend's own theme variables: the
/// entity's `--state-<domain>-<state>-color` when the theme defines one, then its domain's active
/// colour, then the generic one.
public enum HomeStateColor {
    public static func color(for state: HomeEntityState) -> Color {
        if state.isUnavailable {
            return FrontendColors.stateUnavailableColor.color
        }
        guard HomeStateActivity.isActive(domain: state.domain, state: state.state) else {
            return FrontendColors.stateInactiveColor.color
        }
        let domain = state.domain
        let candidates = [
            "--state-\(domain)-\(state.state)-color",
            "--state-\(domain)-active-color",
        ]
        for candidate in candidates {
            if let color = FrontendColors(rawValue: candidate)?.color {
                return color
            }
        }
        return FrontendColors.stateActiveColor.color
    }
}
#endif
