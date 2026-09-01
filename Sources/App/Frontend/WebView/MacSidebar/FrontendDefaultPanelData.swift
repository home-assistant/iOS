import Foundation
import HAKit
import Shared

/// The `default_panel` of the frontend's `core` user data or system data, from the same
/// `{ "value": ... }` envelope as `FrontendSidebarUserData`.
struct FrontendDefaultPanelData: HADataDecodable, Equatable {
    static let dataKey = "core"

    var defaultPanel: String?

    init(defaultPanel: String? = nil) {
        self.defaultPanel = defaultPanel
    }

    init(data: HAData) throws {
        let value: HAData = data.decode("value", fallback: .empty)
        let defaultPanel: String? = try? value.decode("default_panel")
        self.defaultPanel = defaultPanel.flatMap { $0.isEmpty ? nil : $0 }
    }
}
