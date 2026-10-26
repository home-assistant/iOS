import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

/// Holds the URL check behind Save open until the test answers it, so the state in between can be looked at.
private final class PendingSendTestWebhookManager: WebhookManager {
    private(set) var pendingCheck: Resolver<Void>?

    override func sendTest(server: Server, baseURL: URL) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        pendingCheck = seal
        return promise
    }
}

/// Covers what the URL editor derives from its fields: when the security level row applies, when Save
/// has something to save, what a commit writes back, and how Save behaves while its URL check is out.
@Suite(.serialized)
@MainActor
struct ConnectionURLViewModelTests {
    private func makeServer(internalURL: String?, securityLevel: ConnectionSecurityLevel = .mostSecure) -> Server {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com"),
                internalURL: internalURL.flatMap(URL.init(string:)),
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: ["MyWifi"],
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: securityLevel
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        return Server.fake(identifier: .init(rawValue: "test-server"), initial: info)
    }

    @Test func securityLevelRowOnlyForPlainHTTPInternalURL() {
        let server = makeServer(internalURL: "http://internal.example.com:8123")
        let internalViewModel = ConnectionURLViewModel(server: server, urlType: .internal)
        #expect(internalViewModel.showsSecurityLevel)

        internalViewModel.url = "https://internal.example.com:8123"
        #expect(!internalViewModel.showsSecurityLevel)

        internalViewModel.url = "not a url"
        #expect(!internalViewModel.showsSecurityLevel)

        let externalViewModel = ConnectionURLViewModel(server: server, urlType: .external)
        externalViewModel.url = "http://external.example.com"
        #expect(!externalViewModel.showsSecurityLevel)
    }

    @Test func hasChangesFollowsEdits() {
        let server = makeServer(internalURL: "http://internal.example.com:8123")
        let viewModel = ConnectionURLViewModel(server: server, urlType: .internal)
        #expect(!viewModel.hasChanges)

        viewModel.ssids.append("OtherWifi")
        #expect(viewModel.hasChanges)
        viewModel.ssids.removeLast()
        #expect(!viewModel.hasChanges)

        viewModel.securityLevel = .lessSecure
        #expect(viewModel.hasChanges)
        viewModel.securityLevel = .mostSecure

        viewModel.localPush.toggle()
        #expect(viewModel.hasChanges)
        viewModel.localPush.toggle()

        viewModel.url = "http://other.example.com:8123"
        #expect(viewModel.hasChanges)
    }

    @Test func commitWritesSecurityLevelForInternalURLOnly() {
        let server = makeServer(internalURL: "http://internal.example.com:8123")

        let internalViewModel = ConnectionURLViewModel(server: server, urlType: .internal)
        internalViewModel.securityLevel = .lessSecure
        internalViewModel.commitAnyway(onSuccess: {})
        #expect(server.info.connection.connectionAccessSecurityLevel == .lessSecure)
        #expect(!internalViewModel.hasChanges)

        let externalViewModel = ConnectionURLViewModel(server: server, urlType: .external)
        externalViewModel.securityLevel = .undefined
        externalViewModel.commitAnyway(onSuccess: {})
        #expect(server.info.connection.connectionAccessSecurityLevel == .lessSecure)
    }

    /// `isChecking` is what keeps the editor sheet from closing, so it has to stay up for as long as the
    /// check is out and only drop once the error it produced is ready to show.
    @Test func saveStaysCheckingUntilTheURLCheckFailsThenOffersUseAnyway() async throws {
        let previousWebhooks = Current.webhooks
        let webhooks = PendingSendTestWebhookManager()
        Current.webhooks = webhooks
        defer { Current.webhooks = previousWebhooks }

        let server = makeServer(internalURL: "https://internal.example.com:8123")
        let viewModel = ConnectionURLViewModel(server: server, urlType: .external)
        viewModel.url = "http://unreachable.example.com:8123"

        var didSave = false
        viewModel.save(onSuccess: { didSave = true })

        #expect(webhooks.pendingCheck != nil)
        try await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.isChecking)
        #expect(!viewModel.showError)

        // PromiseKit clears `isChecking` and raises the error on separate main queue turns, so wait for the
        // error, which comes last.
        webhooks.pendingCheck?.reject(URLError(.timedOut))
        for _ in 0 ..< 100 where !viewModel.showError {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(!viewModel.isChecking)
        #expect(viewModel.showError)
        #expect(viewModel.canCommitAnyway)
        #expect(!didSave)
        #expect(server.info.connection.address(for: .external) == URL(string: "https://external.example.com"))
    }
}
