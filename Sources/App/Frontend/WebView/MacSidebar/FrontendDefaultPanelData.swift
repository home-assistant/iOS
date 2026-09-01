import Foundation
import HAKit
import Shared

/// The `default_panel` of the frontend's `core` user data or system data, from the same
/// `{ "value": ... }` envelope as `FrontendSidebarUserData`. Keeps the whole `core` value so a write
/// merges into it the way the frontend's profile page does (`{ ...userData, default_panel }`).
struct FrontendDefaultPanelData: HADataDecodable {
    static let dataKey = "core"
    static let defaultPanelKey = "default_panel"

    var defaultPanel: String?
    private(set) var rawValue: [String: Any]

    init(defaultPanel: String? = nil, rawValue: [String: Any] = [:]) {
        self.defaultPanel = defaultPanel
        self.rawValue = rawValue
    }

    init(data: HAData) throws {
        let value: HAData = data.decode("value", fallback: .empty)
        if case let .dictionary(dictionary) = value {
            self.rawValue = dictionary
        } else {
            self.rawValue = [:]
        }
        let defaultPanel: String? = try? value.decode(Self.defaultPanelKey)
        self.defaultPanel = defaultPanel.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The `core` value to save after choosing `path` as this user's default dashboard; every other
    /// key is preserved.
    func settingDefaultPanel(_ path: String) -> Self {
        var value = rawValue
        value[Self.defaultPanelKey] = path
        return Self(defaultPanel: path, rawValue: value)
    }
}
