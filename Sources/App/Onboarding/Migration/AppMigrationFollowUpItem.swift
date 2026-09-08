import Foundation
import Shared

/// What does not come back on its own after the transfer and needs the user's hand.
enum AppMigrationFollowUpItem: CaseIterable, Identifiable {
    case homeScreenWidgets
    case watchApp
    case permissions
    case shortcuts
    case deletePreviousApp

    var id: Self {
        self
    }

    /// The items worth showing before the transfer starts; deleting the previous app only makes
    /// sense once the transfer has succeeded.
    static var beforeTransfer: [Self] {
        allCases.filter { $0 != .deletePreviousApp }
    }

    var icon: MaterialDesignIcons {
        switch self {
        case .homeScreenWidgets: .widgetsOutlineIcon
        case .watchApp: .watchIcon
        case .permissions: .shieldCheckOutlineIcon
        case .shortcuts: .microphoneOutlineIcon
        case .deletePreviousApp: .cellphoneRemoveIcon
        }
    }

    var title: String {
        switch self {
        case .homeScreenWidgets: L10n.AppMigration.FollowUp.HomeScreenWidgets.title
        case .watchApp: L10n.AppMigration.FollowUp.WatchApp.title
        case .permissions: L10n.AppMigration.FollowUp.Permissions.title
        case .shortcuts: L10n.AppMigration.FollowUp.Shortcuts.title
        case .deletePreviousApp: L10n.AppMigration.FollowUp.DeletePreviousApp.title
        }
    }

    var explanation: String {
        switch self {
        case .homeScreenWidgets: L10n.AppMigration.FollowUp.HomeScreenWidgets.explanation
        case .watchApp: L10n.AppMigration.FollowUp.WatchApp.explanation
        case .permissions: L10n.AppMigration.FollowUp.Permissions.explanation
        case .shortcuts: L10n.AppMigration.FollowUp.Shortcuts.explanation
        case .deletePreviousApp: L10n.AppMigration.FollowUp.DeletePreviousApp.explanation
        }
    }
}
