import Foundation
import Shared

/// What the previous app hands over to the new one.
enum AppMigrationTransferredItem: CaseIterable, Identifiable {
    case servers
    case appSettings
    case companionChoices
    case notifications
    case nfcTags

    var id: Self {
        self
    }

    var icon: MaterialDesignIcons {
        switch self {
        case .servers: .serverNetworkIcon
        case .appSettings: .tuneIcon
        case .companionChoices: .watchVariantIcon
        case .notifications: .bellOutlineIcon
        case .nfcTags: .nfcVariantIcon
        }
    }

    var title: String {
        switch self {
        case .servers: L10n.AppMigration.Item.Servers.title
        case .appSettings: L10n.AppMigration.Item.AppSettings.title
        case .companionChoices: L10n.AppMigration.Item.CompanionChoices.title
        case .notifications: L10n.AppMigration.Item.Notifications.title
        case .nfcTags: L10n.AppMigration.Item.NfcTags.title
        }
    }

    var explanation: String {
        switch self {
        case .servers: L10n.AppMigration.Item.Servers.explanation
        case .appSettings: L10n.AppMigration.Item.AppSettings.explanation
        case .companionChoices: L10n.AppMigration.Item.CompanionChoices.explanation
        case .notifications: L10n.AppMigration.Item.Notifications.explanation
        case .nfcTags: L10n.AppMigration.Item.NfcTags.explanation
        }
    }
}
