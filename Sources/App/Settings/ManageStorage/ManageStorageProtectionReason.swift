import Foundation
import Shared

/// Why a `ManageStorageItem` cannot be deleted from this screen.
///
/// Every reason is shown to the user next to the row, so a protected row explains itself instead of
/// looking like a bug.
enum ManageStorageProtectionReason: String, CaseIterable {
    /// Losing it would sign the user out or drop configuration the app cannot rebuild by syncing.
    case essentialAppData
    /// The legacy store still holds records that have not been imported into the app database yet.
    case pendingMigration
    /// Files the user put there themselves, which the app would not be able to restore.
    case userProvidedContent
    /// A folder the app points at but does not own, so wiping it would delete unrelated files.
    case outsideAppControl
    /// A folder that turns out to contain one of the protected rows on this device.
    case holdsProtectedData

    var explanation: String {
        switch self {
        case .essentialAppData:
            return L10n.Settings.Debugging.ManageStorage.Protection.EssentialAppData.explanation
        case .pendingMigration:
            return L10n.Settings.Debugging.ManageStorage.Protection.PendingMigration.explanation
        case .userProvidedContent:
            return L10n.Settings.Debugging.ManageStorage.Protection.UserProvidedContent.explanation
        case .outsideAppControl:
            return L10n.Settings.Debugging.ManageStorage.Protection.OutsideAppControl.explanation
        case .holdsProtectedData:
            return L10n.Settings.Debugging.ManageStorage.Protection.HoldsProtectedData.explanation
        }
    }
}
