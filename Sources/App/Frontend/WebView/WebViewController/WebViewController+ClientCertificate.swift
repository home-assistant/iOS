import Shared
import SwiftUI
import UIKit
import WebKit

// MARK: - Client certificate (mTLS)

extension WebViewController {
    /// Whether a failed load is a client certificate problem rather than a connectivity one, and which.
    ///
    /// `-1206` (`clientCertificateRequired`) and `-1205` (`clientCertificateRejected`) are the codes
    /// CFNetwork reports when the server closes the handshake over the certificate. Some servers don't
    /// close it that cleanly: they answer the challenge and then drop the connection, which surfaces as a
    /// generic secure-connection failure, or as the challenge being cancelled when this device could not
    /// produce a credential. Those are only a certificate problem when the navigation actually received a
    /// client certificate challenge; without one they stay the connectivity failures they look like.
    ///
    /// Which problem it is depends on this device: a server that requires a certificate the device does
    /// not have needs one imported, a server that turns down the one it has needs a valid one imported.
    static func clientCertificateIssue(
        for error: Error,
        receivedClientCertificateChallenge: Bool,
        hasClientCertificate: Bool
    ) -> ClientCertificateIssue? {
        // Matched on domain and code rather than on the `URLError` type, so a failure that arrives as a
        // plain `NSError` in `NSURLErrorDomain` (WebKit hands those over as `Error`) classifies the same.
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return nil }
        let issueForThisDevice: ClientCertificateIssue = hasClientCertificate ? .rejected : .required

        switch URLError.Code(rawValue: nsError.code) {
        case .clientCertificateRequired, .clientCertificateRejected:
            return issueForThisDevice
        case .secureConnectionFailed, .userCancelledAuthentication:
            return receivedClientCertificateChallenge ? issueForThisDevice : nil
        default:
            return nil
        }
    }

    /// Whether the intercepted main-frame response is a reverse proxy turning the request down over the
    /// client certificate: nginx completes the handshake with `ssl_verify_client optional` and answers
    /// `400 Bad Request` ("No required SSL certificate was sent") instead, so no navigation error ever
    /// fires. The 400 alone is not enough — the frontend's own API answers 400 too — the handshake also
    /// has to have asked for a certificate.
    static func isClientCertificateRefusal(statusCode: Int, receivedClientCertificateChallenge: Bool) -> Bool {
        statusCode == 400 && receivedClientCertificateChallenge
    }

    /// Records the certificate problem behind a failed load, if it is one, so the empty state the failure
    /// goes on to show asks for a certificate import rather than a retry.
    func recordClientCertificateIssueIfNeeded(for error: Error) {
        guard let issue = Self.clientCertificateIssue(
            for: error,
            receivedClientCertificateChallenge: didReceiveClientCertificateChallenge,
            hasClientCertificate: server.info.connection.clientCertificate != nil
        ) else { return }
        Current.Log.error("[mTLS] Load failed over the client certificate (\(issue)): \(error)")
        clientCertificateIssue = issue
    }

    /// The certificate problem a proxy's refusal stands for on this device, see `isClientCertificateRefusal`.
    var clientCertificateIssueForRefusal: ClientCertificateIssue {
        server.info.connection.clientCertificate != nil ? .rejected : .required
    }

    /// Takes over an intercepted main-frame error response when it is a proxy refusing the request over
    /// the client certificate (see `isClientCertificateRefusal`): cancels the navigation and shows the
    /// certificate empty state. Returns whether it did, so the caller can fall through to the regular
    /// error-response handling otherwise.
    ///
    /// A connection that already failed over the certificate is reused without a new handshake (and so
    /// without a new challenge), which is why a known problem counts as much as a challenge on this
    /// navigation.
    func handleClientCertificateRefusalIfNeeded(
        statusCode: Int,
        responseURL: URL?,
        decisionHandler: (WKNavigationResponsePolicy) -> Void
    ) -> Bool {
        guard Self.isClientCertificateRefusal(
            statusCode: statusCode,
            receivedClientCertificateChallenge: didReceiveClientCertificateChallenge || clientCertificateIssue != nil
        ) else { return false }

        let issue = clientCertificateIssueForRefusal
        Current.Log.error("[mTLS] Main frame refused over the client certificate (\(issue))")
        clientCertificateIssue = issue
        didHandleServerErrorResponse = true
        decisionHandler(.cancel)
        latestLoadError = Self.serverErrorLoadError(for: responseURL)
        connectionState = Self.connectionStateForInterceptedServerError(current: connectionState)
        showEmptyState()
        return true
    }

    /// Opens the same certificate import the onboarding uses, over the empty state. Importing stores the
    /// certificate on the server and reloads; cancelling leaves the empty state up.
    func presentClientCertificateImport() {
        let controller = UIHostingController(
            rootView: NavigationView { makeClientCertificateImportView() }.navigationViewStyle(.stack)
        )
        controller.modalPresentationStyle = .formSheet
        presentOverlayController(controller: controller, animated: true)
    }

    /// The import sheet's content, with its outcomes wired back into this controller.
    func makeClientCertificateImportView() -> ClientCertificateOnboardingView {
        ClientCertificateOnboardingView(
            onImport: { [weak self] certificate in
                self?.applyImportedClientCertificate(certificate)
            },
            onCancel: { [weak self] in
                self?.dismissOverlayController(animated: true, completion: nil)
            }
        )
    }

    /// Stores the imported certificate on the server and reloads the frontend with it.
    func applyImportedClientCertificate(_ certificate: ClientCertificate) {
        Current.Log.info("[mTLS] Imported client certificate for \(server.identifier): \(certificate.displayName)")
        server.update { info in
            info.connection.clientCertificate = certificate
        }

        clientCertificateIssue = nil
        connectionState = .unknown
        overlayState?.connectionState = .unknown

        dismissOverlayController(animated: true) { [weak self] in
            guard let self else { return }
            hideEmptyState()
            refresh()
        }
    }
}
