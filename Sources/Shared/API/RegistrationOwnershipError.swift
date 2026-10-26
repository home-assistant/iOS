import Foundation

public enum RegistrationOwnershipError: LocalizedError, Equatable {
    case noDeviceIdentifier
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
