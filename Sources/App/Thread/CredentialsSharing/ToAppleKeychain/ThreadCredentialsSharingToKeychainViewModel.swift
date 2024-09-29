import Foundation
import Shared

final class ThreadTransferCredentialToKeychainViewModel: ThreadCredentialsSharingViewModelProtocol {
    @Published var showOperationSuccess: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertType: ThreadCredentialsAlertType?

    private let macExtendedAddress: String
    private let activeOperationalDataset: String

    init(macExtendedAddress: String, activeOperationalDataset: String) {
        self.macExtendedAddress = macExtendedAddress
        self.activeOperationalDataset = activeOperationalDataset
    }

    @MainActor
    func mainOperation() async {
        do {
            try await Current.matter.threadClientService.saveCredential(
                macExtendedAddress: macExtendedAddress,
                operationalDataSet: activeOperationalDataset
            )
            showOperationSuccess = true
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error?) {
        guard let error else { return }
        switch error {
        case ThreadClientServiceError.failedToConvertToHexadecimal:
            Current.Log.error("Failed to convert input to hexadecimal while storing thread credential in keychain")
            alertType = .error(
                title: L10n.Thread.StoreInKeychain.Error.title,
                message: L10n.Thread.StoreInKeychain.Error.HexadecimalConversion.body
            )
        default:
            Current.Log.error("Failed to store thread credential in keychain: \(error.localizedDescription)")
            alertType = .error(
                title: L10n.Thread.StoreInKeychain.Error.title,
                message: L10n.Thread.StoreInKeychain.Error.message(error.localizedDescription)
            )
        }
        showAlert = true
    }
}
