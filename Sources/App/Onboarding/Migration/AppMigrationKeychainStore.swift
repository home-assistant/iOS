import Foundation
import Shared

/// The keychain services worth carrying over, named logically because two of them embed the bundle
/// identifier and therefore differ between the two apps.
enum AppMigrationKeychainStore: String, Codable, CaseIterable {
    case servers
    case app
    case deviceUID
    case watchRegistration
    /// A store this build does not know, from a newer payload; skipped on both sides.
    case unknown

    static var transferred: [Self] {
        allCases.filter { $0 != .unknown }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }

    var service: String {
        switch self {
        case .servers: "io.home-assistant.servers"
        case .app: AppConstants.BundleID
        case .deviceUID: "deviceUID"
        case .watchRegistration: "\(AppConstants.BundleID).watch-device-registration"
        case .unknown: ""
        }
    }
}
