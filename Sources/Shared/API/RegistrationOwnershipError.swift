import Foundation

/// Why `RegistrationOwnership` could not settle a registration.
public enum RegistrationOwnershipError: LocalizedError, Equatable {
    /// The system has no vendor identifier to give yet, which happens until the device is first unlocked.
    case noDeviceIdentifier
    /// The registration belongs to another device, so it is left as it is until this device settles it.
    case registeredByAnotherDevice

    public var errorDescription: String? {
        switch self {
        case .noDeviceIdentifier:
            return L10n.RestoredRegistrations.Errors.noDeviceIdentifier
        case .registeredByAnotherDevice:
            return L10n.RestoredRegistrations.Errors.registeredByAnotherDevice
        }
    }
}
