import Foundation

/// The paths the generated dashboard navigates between. They are the frontend's own, so a tap that
/// the app cannot handle natively can be handed to the web view unchanged.
public enum HomeDashboardPath {
    public static let overview = "overview"
    public static let mediaPlayers = "media-players"
    public static let otherDevices = "other-devices"
    /// Where the frontend sends "add an integration", which the app opens in the web view.
    public static let addIntegration = "/config/integrations/dashboard/add"

    /// An area's own view — `areas-kitchen`.
    public static func area(_ areaId: String) -> String {
        "areas-\(areaId)"
    }

    /// The area id back out of such a path, or `nil` when the path is about something else.
    public static func areaId(from path: String) -> String? {
        guard path.hasPrefix("areas-") else {
            return nil
        }
        return String(path.dropFirst("areas-".count))
    }
}
