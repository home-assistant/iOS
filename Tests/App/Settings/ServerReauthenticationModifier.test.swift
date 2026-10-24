import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Hosts a control carrying `.serverReauthentication` in a key window and checks that each step of
/// a Re-authenticate is actually presented from it: the address picker, the client certificate
/// import, the login page and the failure alert.
@Suite(.serialized)
@MainActor
struct ServerReauthenticationModifierTests {
    private func makeServer(internalURL: String? = nil) -> Server {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com"),
                internalURL: internalURL.flatMap(URL.init(string:)),
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .lessSecure
            ),
            token: .init(accessToken: "old-access", refreshToken: "old-refresh", expiration: Date()),
            version: "2024.1"
        )
        return Server.fake(identifier: .init(rawValue: "modifier-server"), initial: info)
    }

    private func host(_ model: ServerReauthenticationModel, for server: Server) -> (UIWindow, UIViewController) {
        let window = UIWindow(frame: .init(x: 0, y: 0, width: 390, height: 844))
        let controller = UIHostingController(
            rootView: Text(verbatim: "Re-authenticate").serverReauthentication(model, for: server)
        )
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return (window, controller)
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 3000 {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func dismissPresented(_ controller: UIViewController) async {
        controller.dismiss(animated: false)
        _ = await waitUntil { controller.presentedViewController == nil }
    }

    @Test func theAddressPickerIsPresentedFromTheControl() async {
        let server = makeServer(internalURL: "http://internal.example.com:8123")
        let model = ServerReauthenticationModel()
        let (window, controller) = host(model, for: server)
        defer { window.isHidden = true }

        model.start(for: server)

        #expectawait (waitUntil { controller.presentedViewController != nil })
        model.isChoosingURL = false
        await dismissPresented(controller)
    }

    @Test func theCertificateImportThenTheLoginArePresented() async {
        let server = makeServer()
        let model = ServerReauthenticationModel()
        model.reauthenticator.clientCertificateRequirement = { _ in .value(true) }
        let (window, controller) = host(model, for: server)
        defer { window.isHidden = true }

        model.reauthenticate(server, using: .external)
        #expectawait (waitUntil { controller.presentedViewController != nil })
        #expect(model.clientCertificateRequest != nil)

        model.clientCertificateRequest?.complete(with: ClientCertificate(
            keychainIdentifier: "imported",
            displayName: "Imported"
        ))
        #expectawait (waitUntil { model.loginViewModel != nil })
        #expectawait (waitUntil {
            controller.presentedViewController != nil && model.clientCertificateRequest == nil
        })

        model.loginViewModel?.cancel()
        #expectawait (waitUntil { !model.isReauthenticating })
        await dismissPresented(controller)
    }

    @Test func aFailureIsPresentedAsAnAlert() async {
        let server = makeServer()
        let model = ServerReauthenticationModel()
        model.reauthenticator.clientCertificateRequirement = { _ in Promise(error: URLError(.notConnectedToInternet)) }
        let (window, controller) = host(model, for: server)
        defer { window.isHidden = true }

        model.reauthenticate(server, using: .external)

        #expectawait (waitUntil { model.error != nil })
        #expectawait (waitUntil { controller.presentedViewController is UIAlertController })
        model.error = nil
        await dismissPresented(controller)
    }
}
