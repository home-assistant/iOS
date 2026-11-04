import PromiseKit
import Shared
import SwiftUI

/// Runs a Re-authenticate started from the settings: asks which address to sign in through when there
/// is a choice, presents the login page (and the client certificate import when the server asks for
/// one it was never given), then lets a web view showing the server reload. One model can serve a
/// whole list of servers; the bindings are scoped to the server whose sign in is running, so only the
/// row or button that started it presents anything.
@MainActor
final class ServerReauthenticationModel: ObservableObject {
    /// The server whose picker, sign in or error is on screen.
    @Published private(set) var activeServerID: Identifier<Server>?
    @Published private(set) var isReauthenticating = false
    @Published var isChoosingURL = false
    @Published var loginViewModel: OnboardingAuthLoginViewModel?
    @Published var clientCertificateRequest: OnboardingClientCertificateRequest?
    @Published var error: Error?

    var reauthenticator = ServerReauthenticator()

    /// The addresses `server` can be signed in through, most preferred first.
    func urlTypes(for server: Server) -> [ConnectionInfo.URLType] {
        server.info.connection.availableAuthenticationURLTypes
    }

    func isReauthenticating(_ server: Server) -> Bool {
        isReauthenticating && activeServerID == server.identifier
    }

    /// What the Re-authenticate button or menu item does: asks which address to use when there is a
    /// choice, otherwise signs in through the only one.
    func start(for server: Server) {
        guard !isReauthenticating else { return }
        let urlTypes = urlTypes(for: server)
        if urlTypes.count > 1 {
            activeServerID = server.identifier
            isChoosingURL = true
        } else if let urlType = urlTypes.first {
            reauthenticate(server, using: urlType)
        }
    }

    /// Signs in to `server` again through `urlType` and swaps in the new token, keeping its URLs,
    /// webhook and device registration.
    func reauthenticate(_ server: Server, using urlType: ConnectionInfo.URLType) {
        guard !isReauthenticating else { return }
        activeServerID = server.identifier
        isReauthenticating = true
        error = nil

        reauthenticator.reauthenticate(
            server,
            using: urlType,
            login: { [self] authDetails in
                let viewModel = OnboardingAuthLoginViewModel(authDetails: authDetails)
                loginViewModel = viewModel
                return viewModel.resultPromise.ensure { [weak self] in self?.loginViewModel = nil }
            },
            importClientCertificate: { [self] in
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
        ).done {
            Current.Log.info("Re-authenticated server \(server.identifier.rawValue) from settings")
            let connection = Current.api(for: server)?.connection
            connection?.disconnect()
            connection?.connect()
            NotificationCenter.default.post(name: ServerReauthenticator.didReauthenticateNotification, object: server)
        }.ensure { [weak self] in
            self?.isReauthenticating = false
        }.catch(policy: .allErrors) { [weak self] error in
            if let pmkError = error as? PMKError, pmkError.isCancelled {
                Current.Log.info("Re-authentication from settings cancelled by user")
                return
            }
            Current.Log.error("Re-authentication from settings failed: \(error)")
            self?.error = error
        }
    }

    // MARK: - Bindings scoped to one server

    func urlPickerBinding(for server: Server) -> Binding<Bool> {
        Binding(
            get: { [self] in isChoosingURL && activeServerID == server.identifier },
            set: { [self] in isChoosingURL = $0 }
        )
    }

    func loginBinding(for server: Server) -> Binding<OnboardingAuthLoginViewModel?> {
        Binding(
            get: { [self] in activeServerID == server.identifier ? loginViewModel : nil },
            set: { [self] in loginViewModel = $0 }
        )
    }

    /// The certificate import as a SwiftUI sheet, on iOS. Dismissing it without choosing a certificate
    /// cancels the sign in.
    func certificateRequestBinding(for server: Server) -> Binding<OnboardingClientCertificateRequest?> {
        Binding(
            get: { [self] in Current.isCatalyst ? nil : certificateRequest(for: server) },
            set: { [self] in if $0 == nil { clientCertificateRequest?.cancel() } }
        )
    }

    /// The certificate import on Mac Catalyst, where SwiftUI sheet content doesn't receive mouse events
    /// reliably, so it is presented as a UIKit form sheet instead.
    func certificateFormSheetRequest(for server: Server) -> OnboardingClientCertificateRequest? {
        Current.isCatalyst ? certificateRequest(for: server) : nil
    }

    private func certificateRequest(for server: Server) -> OnboardingClientCertificateRequest? {
        activeServerID == server.identifier ? clientCertificateRequest : nil
    }

    /// Dismissing the failure alert clears the error.
    func errorBinding(for server: Server) -> Binding<Bool> {
        Binding(
            get: { [self] in error != nil && activeServerID == server.identifier },
            set: { [self] in if !$0 { error = nil } }
        )
    }
}
