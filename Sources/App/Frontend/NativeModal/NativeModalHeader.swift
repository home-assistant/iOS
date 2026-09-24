import Foundation

/// The header of a native modal as the frontend describes it in `modal/header`.
///
/// The frontend decides what the header offers; the bar draws exactly this and reports a tap with
/// `modal/action` and the item's `id`. Nothing here is known to the app ahead of time.
struct NativeModalHeader: Equatable {
    /// What the leading button does.
    enum Navigation: String {
        /// Dismiss the sheet.
        case close
        /// Return to whatever the page was showing before.
        case back
    }

    /// An icon button in the bar.
    struct Action: Equatable, Identifiable {
        let id: String
        /// Translated by the frontend, for accessibility.
        let label: String
        /// An MDI icon name, like `mdi:chart-box-outline`.
        let icon: String

        init?(payload: [String: Any]) {
            guard let id = payload["id"] as? String,
                  let label = payload["label"] as? String,
                  let icon = payload["icon"] as? String else { return nil }
            self.id = id
            self.label = label
            self.icon = icon
        }

        init(id: String, label: String, icon: String) {
            self.id = id
            self.label = label
            self.icon = icon
        }
    }

    /// An item of the overflow menu.
    struct MenuItem: Equatable, Identifiable {
        let id: String
        let label: String
        let icon: String
        let isDisabled: Bool
        /// A separator follows this item.
        let hasDividerAfter: Bool

        init?(payload: [String: Any]) {
            guard let action = Action(payload: payload) else { return nil }
            self.id = action.id
            self.label = action.label
            self.icon = action.icon
            self.isDisabled = payload["disabled"] as? Bool ?? false
            self.hasDividerAfter = payload["divider_after"] as? Bool ?? false
        }

        init(id: String, label: String, icon: String, isDisabled: Bool = false, hasDividerAfter: Bool = false) {
            self.id = id
            self.label = label
            self.icon = icon
            self.isDisabled = isDisabled
            self.hasDividerAfter = hasDividerAfter
        }
    }

    let title: String
    let subtitle: String?
    let navigation: Navigation
    /// Translated accessibility label of the leading button.
    let navigationLabel: String
    /// Translated accessibility label of the overflow menu button.
    let menuLabel: String
    let actions: [Action]
    let menu: [MenuItem]

    init?(payload: [String: Any]?) {
        guard let payload,
              let title = payload["title"] as? String else { return nil }
        self.title = title
        self.subtitle = payload["subtitle"] as? String
        self.navigation = (payload["navigation"] as? String).flatMap(Navigation.init(rawValue:)) ?? .close
        self.navigationLabel = payload["navigation_label"] as? String ?? ""
        self.menuLabel = payload["menu_label"] as? String ?? ""
        self.actions = (payload["actions"] as? [[String: Any]] ?? []).compactMap(Action.init(payload:))
        self.menu = (payload["menu"] as? [[String: Any]] ?? []).compactMap(MenuItem.init(payload:))
    }

    init(
        title: String,
        subtitle: String? = nil,
        navigation: Navigation = .close,
        navigationLabel: String = "",
        menuLabel: String = "",
        actions: [Action] = [],
        menu: [MenuItem] = []
    ) {
        self.title = title
        self.subtitle = subtitle
        self.navigation = navigation
        self.navigationLabel = navigationLabel
        self.menuLabel = menuLabel
        self.actions = actions
        self.menu = menu
    }
}
