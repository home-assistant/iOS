import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
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
@Suite(.sharedState)
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

    // MARK: - Errors, networks and saving

    @Test func saveErrorsDescribeThemselvesAndAreFinal() {
        let errors: [ConnectionURLViewModel.SaveError] = [.lastURL, .validation("Bad address")]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
            #expect(error.isFinal)
        }
        #expect(ConnectionURLViewModel.SaveError.validation("Bad address").errorDescription == "Bad address")
    }

    @Test func onlyInternalAndExternalURLsHaveAPlaceholder() {
        let server = makeServer(internalURL: nil)
        #expect(!ConnectionURLViewModel(server: server, urlType: .internal).placeholder.isEmpty)
        #expect(!ConnectionURLViewModel(server: server, urlType: .external).placeholder.isEmpty)
        #expect(ConnectionURLViewModel(server: server, urlType: .remoteUI).placeholder.isEmpty)
    }

    /// Adding a network fills in the one the device is on, or an empty row to type into when it is
    /// already listed (or unknown); rows can be removed one by one or in bulk.
    @Test func networksAreAddedFromTheCurrentConnection() async {
        let connectivity = Current.connectivity
        let previousState = connectivity.currentNetworkState
        connectivity.currentNetworkState = { NetworkState(ssid: "Home Wi-Fi", hardwareAddress: "aa:bb:cc:dd:ee:ff") }
        defer { connectivity.currentNetworkState = previousState }

        let viewModel = ConnectionURLViewModel(server: makeServer(internalURL: nil), urlType: .internal)
        viewModel.ssids = []
        viewModel.addSSID()
        await waitUntil { viewModel.ssids == ["Home Wi-Fi"] }
        viewModel.addSSID()
        await waitUntil { viewModel.ssids == ["Home Wi-Fi", ""] }
        viewModel.removeSSID(at: 1)
        viewModel.removeSSIDs(at: IndexSet(integer: 0))
        #expect(viewModel.ssids.isEmpty)

        viewModel.addHardwareAddress()
        await waitUntil { viewModel.hardwareAddresses == ["aa:bb:cc:dd:ee:ff"] }
        viewModel.addHardwareAddress()
        await waitUntil { viewModel.hardwareAddresses.count == 2 }
        #expect(viewModel.hardwareAddresses.last == "")
        viewModel.removeHardwareAddress(at: 1)
        viewModel.removeHardwareAddresses(at: IndexSet(integer: 0))
        #expect(viewModel.hardwareAddresses.isEmpty)
    }

    /// Clearing a URL while the other one remains needs no check and saves straight away; with
    /// Home Assistant Cloud on, the cloud address is what gets checked.
    @Test func savesThatPassTheirCheckAreCommitted() async {
        let previousWebhooks = Current.webhooks
        Current.webhooks = PassingSendTestWebhookManager()
        defer { Current.webhooks = previousWebhooks }

        let server = makeServer(internalURL: "http://internal.example.com:8123")
        let clearing = ConnectionURLViewModel(server: server, urlType: .internal)
        clearing.url = ""
        var saved = 0
        clearing.save { saved += 1 }
        await waitUntil { saved == 1 }
        #expect(server.info.connection.address(for: .internal) == nil)

        server.update {
            $0.connection.set(address: URL(string: "https://example.ui.nabu.casa"), for: .remoteUI)
        }
        let cloud = ConnectionURLViewModel(server: server, urlType: .external)
        cloud.useCloud = true
        cloud.save { saved += 1 }
        await waitUntil { saved == 2 }
        #expect(server.info.connection.useCloud)
    }

    /// Removing the only URL left is refused outright, with no way to save anyway.
    @Test func removingTheLastURLIsRefused() async {
        let server = makeServer(internalURL: nil)
        server.update { $0.connection.set(address: nil, for: .external) }
        let viewModel = ConnectionURLViewModel(server: server, urlType: .internal)
        viewModel.url = ""
        viewModel.useCloud = false
        viewModel.save {}
        await waitUntil { viewModel.showError }
        #expect(viewModel.showError)
        #expect(!viewModel.canCommitAnyway)
        #expect(viewModel.errorMessage == L10n.Settings.ConnectionSection.Errors.cannotRemoveLastUrl)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 1000 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

/// Answers every URL check at once.
private final class PassingSendTestWebhookManager: WebhookManager {
    override func sendTest(server: Server, baseURL: URL) -> Promise<Void> {
        .value(())
    }
}
