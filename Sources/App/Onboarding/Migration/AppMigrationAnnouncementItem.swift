import Foundation
import Shared

/// The three things the previous app tells the user before offering the transfer.
enum AppMigrationAnnouncementItem: CaseIterable, Identifiable {
    case newApp
    case setupMoves
    case followUp

    var id: Self {
        self
    }

    var icon: MaterialDesignIcons {
        switch self {
        case .newApp: .cellphoneArrowDownIcon
        case .setupMoves: .transferIcon
        case .followUp: .shieldCheckOutlineIcon
        }
    }

    var title: String {
        switch self {
        case .newApp: L10n.AppMigration.Announcement.NewApp.title
        case .setupMoves: L10n.AppMigration.Announcement.SetupMoves.title
        case .followUp: L10n.AppMigration.Announcement.FollowUp.title
        }
    }

    var explanation: String {
        switch self {
        case .newApp: L10n.AppMigration.Announcement.NewApp.explanation
        case .setupMoves: L10n.AppMigration.Announcement.SetupMoves.explanation
        case .followUp: L10n.AppMigration.Announcement.FollowUp.explanation
        }
    }
}
