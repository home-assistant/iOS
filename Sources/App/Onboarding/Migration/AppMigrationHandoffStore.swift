import Foundation
import Shared

/// Persists the previous app's handoff phase in the app-group defaults, so a relaunch lands on the
/// transfer screen instead of reconnecting. Readable without the main actor, for launch-time checks.
enum AppMigrationHandoffStore {
    private static let phaseKey = "appMigrationHandoffPhase"
    private static let sessionIDKey = "appMigrationHandoffSessionID"
    private static let sessionKeyKey = "appMigrationHandoffSessionKey"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.AppGroupID)
    }

    static var isActive: Bool {
        defaults?.string(forKey: phaseKey) != nil
    }

    static func load() -> AppMigrationHandoffPhase? {
        switch defaults?.string(forKey: phaseKey) {
        case "requested":
            guard let id = defaults?.string(forKey: sessionIDKey).flatMap(UUID.init(uuidString:)),
                  let key = defaults?.string(forKey: sessionKeyKey),
                  let session = AppMigrationSession(id: id, keyString: key) else { return nil }
            return .requested(session)
        case "handedOff":
            return .handedOff
        case "erased":
            return .erased
        default:
            return nil
        }
    }

    static func save(_ phase: AppMigrationHandoffPhase?) {
        guard let defaults else { return }
        defaults.removeObject(forKey: sessionIDKey)
        defaults.removeObject(forKey: sessionKeyKey)
        switch phase {
        case let .requested(session):
            defaults.set("requested", forKey: phaseKey)
            defaults.set(session.id.uuidString, forKey: sessionIDKey)
            defaults.set(session.keyString, forKey: sessionKeyKey)
        case .handedOff:
            defaults.set("handedOff", forKey: phaseKey)
        case .erased:
            defaults.set("erased", forKey: phaseKey)
        case nil:
            defaults.removeObject(forKey: phaseKey)
        }
    }
}
