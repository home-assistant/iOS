@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The sheet that explains a failed connection. Each case renders a different set of sections: the
/// failing URL, the cloud notice (used or switched off), the troubleshooting checks and the settings
/// entry, so each one is rendered once.
@MainActor
struct ConnectionErrorDetailsViewRenderTests {
    private enum PlainError: Error {
        case failed
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1800))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    private func server(remoteUI: Bool, useCloud: Bool, externalURL: URL?, internalURL: URL?) -> Server {
        Server.fake { info in
            var connection = ConnectionInfo(
                externalURL: externalURL,
                internalURL: internalURL,
                cloudhookURL: nil,
                remoteUIURL: remoteUI ? URL(string: "https://remote.ui.nabu.casa") : nil,
                webhookID: "webhook",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .undefined
            )
            connection.useCloud = useCloud
            info.connection = connection
        }
    }

    @Test func rendersAPlainErrorWithoutAServer() {
        render(ConnectionErrorDetailsView(server: nil, error: PlainError.failed))
        render(ConnectionErrorDetailsView(
            server: nil,
            error: PlainError.failed,
            showSettingsEntry: false,
            expandMoreDetails: true
        ))
    }

    @Test(arguments: [false, true])
    func rendersTheFailingURLAndItsTroubleshooting(expanded: Bool) throws {
        let url = try #require(URL(string: "https://homeassistant.example.com:8123"))
        let error = URLError(.cannotConnectToHost, userInfo: [NSURLErrorFailingURLErrorKey: url])
        render(ConnectionErrorDetailsView(server: nil, error: error, expandMoreDetails: expanded))
    }

    @Test(arguments: [true, false])
    func rendersTheCloudNotice(useCloud: Bool) throws {
        let server = server(
            remoteUI: true,
            useCloud: useCloud,
            externalURL: URL(string: "https://external.example.com"),
            internalURL: nil
        )
        render(ConnectionErrorDetailsView(server: server, error: PlainError.failed, expandMoreDetails: true))
    }

    @Test func troubleshootsTheInternalURLWhenThereIsNoExternalOne() {
        let server = server(
            remoteUI: false,
            useCloud: false,
            externalURL: nil,
            internalURL: URL(string: "http://homeassistant.local:8123")
        )
        render(ConnectionErrorDetailsView(server: server, error: PlainError.failed, expandMoreDetails: true))
    }

    @Test func rendersWithoutTroubleshootingWhenNoURLIsKnown() {
        let server = server(remoteUI: false, useCloud: false, externalURL: nil, internalURL: nil)
        render(ConnectionErrorDetailsView(server: server, error: PlainError.failed, expandMoreDetails: true))
    }
}
