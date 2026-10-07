import Foundation
import HAKit
import Shared

/// The `sidebar` key of the frontend's per-user data: the order the user gave the panels and the
/// panels they hid. Decodes the `{ "value": ... }` envelope of `frontend/get_user_data` and
/// `frontend/subscribe_user_data`; a `null` value means the user never customised the sidebar.
///
/// Edits mirror the frontend's `dialog-edit-sidebar.ts`: `panelOrder` is the full ordered list of
/// visible panel paths and `hiddenPanels` the paths the user hid, saved back with
/// `frontend/set_user_data` under the same key so both sidebars stay in sync.
struct FrontendSidebarUserData: HADataDecodable, Equatable {
    static let userDataKey = "sidebar"

    var panelOrder: [String]?
    var hiddenPanels: [String]?

    init(panelOrder: [String]? = nil, hiddenPanels: [String]? = nil) {
        self.panelOrder = panelOrder
        self.hiddenPanels = hiddenPanels
    }

    init(data: HAData) throws {
        let value: HAData = data.decode("value", fallback: .empty)
        let panelOrder: [String]? = try? value.decode("panelOrder")
        let hiddenPanels: [String]? = try? value.decode("hiddenPanels")
        self.panelOrder = panelOrder
        self.hiddenPanels = hiddenPanels
    }

    var isCustomised: Bool {
        panelOrder != nil || hiddenPanels != nil
    }

    /// The JSON value the frontend stores; an empty dictionary resets the sidebar to its defaults.
    var encoded: [String: Any] {
        var value: [String: Any] = [:]
        if let panelOrder {
            value["panelOrder"] = panelOrder
        }
        if let hiddenPanels {
            value["hiddenPanels"] = hiddenPanels
        }
        return value
    }

    /// The user data after moving the visible panels into `visibleOrder`.
    func reordered(to visibleOrder: [String]) -> Self {
        Self(panelOrder: visibleOrder, hiddenPanels: hiddenPanels ?? [])
    }

    /// The user data after hiding `path`. `visibleOrder` seeds the order the first time the user
    /// customises the sidebar so the remaining panels keep their current positions.
    func hiding(_ path: String, visibleOrder: [String]) -> Self {
        var order = panelOrder ?? visibleOrder
        order.removeAll { $0 == path }
        var hidden = hiddenPanels ?? []
        if !hidden.contains(path) {
            hidden.append(path)
        }
        return Self(panelOrder: order, hiddenPanels: hidden)
    }

    /// The user data after showing `path` again, appended at the end of the visible panels. Being in
    /// the order is also what makes a `default_visible == false` panel appear at all.
    func showing(_ path: String, visibleOrder: [String]) -> Self {
        var order = panelOrder ?? visibleOrder
        if !order.contains(path) {
            order.append(path)
        }
        var hidden = hiddenPanels ?? []
        hidden.removeAll { $0 == path }
        return Self(panelOrder: order, hiddenPanels: hidden)
    }
}

extension HATypedRequest {
    static func frontendUserData(key: String) -> Self {
        Self(request: .init(type: "frontend/get_user_data", data: ["key": key]))
    }

    static func frontendSystemData(key: String) -> Self {
        Self(request: .init(type: "frontend/get_system_data", data: ["key": key]))
    }
}

extension HATypedRequest where ResponseType == HAResponseVoid {
    static func setFrontendUserData(key: String, value: [String: Any]) -> Self {
        Self(request: .init(type: "frontend/set_user_data", data: ["key": key, "value": value]))
    }
}

extension HATypedSubscription {
    static func frontendUserData(key: String) -> Self {
        Self(request: .init(type: "frontend/subscribe_user_data", data: ["key": key]))
    }
}
