import Foundation

/// What a tap on a card does. The port of the frontend's tap actions, cut to the four the home
/// dashboard's strategies actually emit.
///
/// The renderer never performs one: it hands the action back to whoever presented the dashboard,
/// because navigating and calling a service are both the app's business.
public enum HomeDashboardAction: Equatable, Hashable, Sendable {
    /// Go to a dashboard path (`"areas-kitchen"`) or a panel (`"/energy?historyBack=1"`).
    case navigate(String)
    /// Call a service against a target — `light.turn_off` for a whole area, say.
    case performAction(HomeServiceCall)
    /// Open the entity's more-info dialog.
    case moreInfo(String)
}
