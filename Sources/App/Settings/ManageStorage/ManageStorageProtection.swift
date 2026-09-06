import Foundation

/// Whether the user is allowed to delete a row on the "Manage Storage" screen.
enum ManageStorageProtection: Equatable {
    case deletable
    case protected(ManageStorageProtectionReason)

    var isDeletable: Bool {
        switch self {
        case .deletable:
            return true
        case .protected:
            return false
        }
    }

    var reason: ManageStorageProtectionReason? {
        switch self {
        case .deletable:
            return nil
        case let .protected(reason):
            return reason
        }
    }
}
