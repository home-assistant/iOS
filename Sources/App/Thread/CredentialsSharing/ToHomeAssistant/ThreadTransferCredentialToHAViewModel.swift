import Foundation
import HAKit
import Shared

final class ThreadTransferCredentialToHAViewModel: ThreadCredentialsSharingViewModelProtocol {
    @Published var credentials: [ThreadCredential] = []
    @Published var showAlert = false
    @Published var alertType: ThreadCredentialsAlertType?
    @Published var showOperationSuccess = false

    private let threadClient: ThreadClientProtocol
    private let connection: HAConnection
    private var credentialsToImport: [String] = []

    init(server: Server, threadClient: ThreadClientProtocol) {
        self.threadClient = threadClient
        self.connection = Current.api(for: server).connection
    }

    @MainActor
    func mainOperation() async {
        do {
            credentials = try await threadClient.retrieveAllCredentials()

            if credentials.isEmpty {
                showAlert(type: .empty(
                    title: L10n.Thread.Credentials.ShareCredentials.noCredentialsTitle,
                    message: L10n.Thread.Credentials.ShareCredentials.noCredentialsMessage
                ))
            } else {
                credentialsToImport = credentials.map(\.activeOperationalDataSet)
                processImport()
            }
        } catch {
            showAlert(type: .error(title: L10n.errorLabel, message: error.localizedDescription))
        }
    }

    @MainActor
    private func processImport() {
        guard let first = credentialsToImport.first else {
            showOperationSuccess = true
            return
        }

        shareCredentialWithHomeAssistant(credential: first) { [weak self] success in
            if success {
                self?.credentialsToImport.removeFirst()
                self?.processImport()
            }
        }
    }

    @MainActor
    private func shareCredentialWithHomeAssistant(credential: String, completion: @escaping (Bool) -> Void) {
        let request = HARequest(type: .webSocket("thread/add_dataset_tlv"), data: [
            "tlv": credential,
            "source": "iOS-app",
        ])
        connection.send(request).promise.pipe { [weak self] result in
            guard let self else { return }
            switch result {
            case .fulfilled:
                completion(true)
            case let .rejected(error):
                showAlert(type: .error(
                    title: L10n.errorLabel,
                    message: error.localizedDescription
                ))
                completion(false)
            }
        }
    }

    private func showAlert(type: ThreadCredentialsAlertType) {
        alertType = type
        showAlert = true
    }
}
