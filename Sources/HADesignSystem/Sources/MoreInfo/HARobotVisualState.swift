import Foundation

/// What a robot vacuum or lawn mower is doing, as its status illustration draws it.
///
/// Frontend counterpart: `computeVisualState` in `ha-state-control-vacuum-status` and
/// `ha-state-control-lawn_mower-status`, which reduce each domain's states to the same six.
/// Unavailable maps to `idle`, as it does there.
public enum HARobotVisualState: String, CaseIterable, Sendable {
    case idle
    /// Cleaning or mowing.
    case active
    case returning
    case paused
    case docked
    case error

    var bodyOpacity: Double {
        switch self {
        case .idle: 0.65
        case .paused: 0.7
        case .docked: 0.75
        case .active, .returning, .error: 1
        }
    }

    var glowOpacity: Double {
        self == .error ? 0.2 : 0.06
    }
}
