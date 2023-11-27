//
//  ThreadCredentialsSharingViewModel.swift
//  App
//
//  Created by Bruno Pantaleão on 24/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import HAKit
import Shared

@available(iOS 13, *)
final class ThreadCredentialsSharingViewModel: ObservableObject {
    enum AlertType {
        case success(title: String)
        case error(title: String, message: String)
    }
    
    @Published var credentials: [ThreadCredential] = []
    @Published var showAlert = false
    @Published var showLoader = false
    @Published var alertType: AlertType?

    private let threadClient: THClientProtocol
    private let connection: HAConnection

    init(server: Server, threadClient: THClientProtocol) {
        self.threadClient = threadClient
        self.connection = Current.api(for: server).connection
    }

    @MainActor
    func retrieveAllCredentials() async {
        showLoader = true
        do {
            credentials = try await threadClient.retrieveAllCredentials()
        } catch let error {
            showAlert(type: .error(title: L10n.errorLabel, message: "Error message: \(error.localizedDescription)"))
        }
        showLoader = false
    }

    @MainActor
    func shareCredentialWithHomeAssistant(credential: ThreadCredential) {
        let request = HARequest(type: .webSocket("thread/add_dataset_tlv"), data: [
            "tlv": credential.activeOperationalDataSet,
            "source": "iOS-app"
        ])
        connection.send(request).promise.pipe { [weak self] result in
            guard let self else { return }
            switch result {
            case .fulfilled(_):
                self.showAlert(type: .success(title: L10n.successLabel))
            case .rejected(let error):
                self.showAlert(type: .error(title: L10n.errorLabel, message: "Error message: \(error.localizedDescription)"))
            }
        }
    }

    private func showAlert(type: AlertType) {
        alertType = type
        showAlert = true
    }
}
