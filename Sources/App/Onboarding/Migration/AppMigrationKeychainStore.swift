import Foundation
import Shared

/// The keychain services worth carrying over, named logically because two of them embed the bundle
/// identifier and therefore differ between the two apps.
enum AppMigrationKeychainStore: String, Codable, CaseIterable {
    case servers
    case app
    case deviceUID
    case watchRegistration

    var service: String {
        switch self {
        case .servers: "io.home-assistant.servers"
        case .app: AppConstants.BundleID
        case .deviceUID: "deviceUID"
        case .watchRegistration: "\(AppConstants.BundleID).watch-device-registration"
        }
    }
}
