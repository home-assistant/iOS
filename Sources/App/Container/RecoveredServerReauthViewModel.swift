import PromiseKit
import Shared
import SwiftUI

@MainActor
final class RecoveredServerReauthViewModel: ObservableObject {
    @Published var loginViewModel: OnboardingAuthLoginViewModel?
    @Published var clientCertificateRequest: OnboardingClientCertificateRequest?

    let server: Server
    let state: OnboardingStateObservable

    init(server: Server, state: OnboardingStateObservable) {
        self.server = server
        self.state = state
    }

    var availableReauthURLTypes: [ConnectionInfo.URLType] {
        state.availableReauthURLTypes(for: server)
    }

    func reauthenticate(
        using urlType: ConnectionInfo.URLType,
        completion: @escaping (Swift.Result<Void, Error>) -> Void
    ) {
        state.performRecoveredServerReauthentication(
            for: server,
            using: urlType,
            login: { [self] in login($0) },
            importClientCertificate: { [self] in importClientCertificate() },
            completion: completion
        )
    }

    func selectServer(_ server: Server) {
        state.handleRecoveredServerSelection(server)
    }

    func login(_ authDetails: OnboardingAuthDetails) -> Promise<OnboardingAuthLoginResult> {
        let viewModel = OnboardingAuthLoginViewModel(authDetails: authDetails)
        loginViewModel = viewModel
        return viewModel.resultPromise.ensure { [weak self] in
            self?.loginViewModel = nil
        }
    }

    func importClientCertificate() -> Promise<ClientCertificate> {
        Promise { seal in
            clientCertificateRequest = OnboardingClientCertificateRequest(
                onImport: { [weak self] certificate in
                    self?.clientCertificateRequest = nil
                    seal.fulfill(certificate)
                },
                onCancel: { [weak self] in
                    self?.clientCertificateRequest = nil
                    seal.reject(PMKError.cancelled)
                }
            )
        }
    }

    var presentsCertificateImportAsPage: Bool {
        Current.isCatalyst && clientCertificateRequest != nil
    }

    var certificateImportSheetRequest: OnboardingClientCertificateRequest? {
        Current.isCatalyst ? nil : clientCertificateRequest
    }

    var certificateImportPageBinding: Binding<Bool> {
        Binding(
            get: { [self] in presentsCertificateImportAsPage },
            set: { [self] presented in if !presented { cancelCertificateImport() } }
        )
    }

    var certificateImportSheetBinding: Binding<OnboardingClientCertificateRequest?> {
        Binding(
            get: { [self] in certificateImportSheetRequest },
            set: { [self] request in if request == nil { cancelCertificateImport() } }
        )
    }

    func cancelCertificateImport() {
        clientCertificateRequest?.cancel()
    }
}
