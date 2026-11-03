import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// The Thread credential screens and the view models behind them, driven with a scripted Thread
/// client and mock WebSocket connections. The management view model reads `Current.matter` and
/// `Current.servers` from PromiseKit callbacks, so the suite swaps the global environment.
@MainActor
@Suite(.sharedState)
struct ThreadCredentialFlowsTests {
    private enum TestError: Error {
        case failed
    }

    private final class ScriptedThreadClient: ThreadClientProtocol {
        var credentials: [ThreadCredential] = []
        var retrieveError: Error?
        var saveError: Error?
        var saved: [String] = []
        var deleted: [String] = []

        func retrieveAllCredentials() async throws -> [ThreadCredential] {
            if let retrieveError { throw retrieveError }
            return credentials
        }

        func saveCredential(macExtendedAddress: String, operationalDataSet: String) async throws {
            if let saveError { throw saveError }
            saved.append(operationalDataSet)
        }

        func saveCredential(
            macExtendedAddress: String,
            operationalDataSet: String,
            completion: @escaping (Error?) -> Void
        ) {
            completion(saveError)
        }

        func deleteCredential(macExtendedAddress: String, completion: @escaping (Error?) -> Void) {
            deleted.append(macExtendedAddress)
            completion(TestError.failed)
        }
    }

    private static func credential(_ name: String) -> ThreadCredential {
        .init(
            networkName: name,
            networkKey: "key-\(name)",
            extendedPANID: "pan-\(name)",
            borderAgentID: "agent-\(name)",
            macExtendedAddress: "mac-\(name)",
            activeOperationalDataSet: "tlv-\(name)",
            pskc: "pskc",
            channel: 15,
            panID: "1234"
        )
    }

    private final class Environment {
        let client = ScriptedThreadClient()
        let servers = FakeServerManager()
        var connections: [HAMockConnection] = []
        private let previousClient = Current.matter.threadClientService
        private let previousServers = Current.servers
        private let previousApis = Current.cachedApis

        init(serverCount: Int = 1) {
            Current.matter.threadClientService = client
            Current.servers = servers
            for _ in 0 ..< serverCount {
                let server = servers.addFake()
                let api = HomeAssistantAPI(server: server)
                let connection = HAMockConnection()
                api.connection = connection
                Current.cachedApis[server.identifier] = api
                connections.append(connection)
            }
        }

        func restore() {
            Current.matter.threadClientService = previousClient
            Current.servers = previousServers
            Current.cachedApis = previousApis
            // A test that stops early leaves requests unanswered; drop them so nothing keeps the APIs alive.
            for connection in connections {
                connection.pendingRequests.removeAll()
                connection.pendingSubscriptions.removeAll()
            }
        }
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// Waits up to 10 s for `condition` and throws when it never holds, so a caller never goes on to
    /// index a request that was not sent.
    private func requireEventually(
        _ condition: () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let met = await waitUntil(condition)
        try #require(met, sourceLocation: sourceLocation)
    }

    private func render(_ view: some View, settle: () async -> Void = {}) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        await settle()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    // MARK: - Management view model

    @Test func loadingListsTheKeychainCredentials() async {
        let environment = Environment()
        defer { environment.restore() }
        environment.client.credentials = [Self.credential("home"), Self.credential("office")]

        let viewModel = ThreadCredentialsManagementViewModel()
        await viewModel.loadCredentials()
        #expect(viewModel.configs.count == 1)
        #expect(viewModel.configs.first?.source == .Apple)
        #expect(viewModel.configs.first?.credentials.map(\.networkName) == ["home", "office"])

        environment.client.retrieveError = TestError.failed
        await viewModel.loadCredentials()
        #expect(viewModel.configs.isEmpty)
    }

    @Test func transferToHomeAssistantReportsWhetherEveryServerAccepted() async throws {
        let environment = Environment(serverCount: 2)
        defer { environment.restore() }
        let viewModel = ThreadCredentialsManagementViewModel()

        var results: [Bool] = []
        viewModel.transfer(Self.credential("home"), to: .HomeAssistant) { results.append($0) }
        try await requireEventually { environment.connections.allSatisfy { $0.pendingRequests.count == 1 } }
        environment.connections[0].pendingRequests[0].completion(.success(.empty))
        environment.connections[1].pendingRequests[0].completion(.success(.empty))
        try await requireEventually { results == [true] }

        viewModel.transfer(Self.credential("home"), to: .HomeAssistant) { results.append($0) }
        try await requireEventually { environment.connections.allSatisfy { $0.pendingRequests.count == 2 } }
        environment.connections[0].pendingRequests[1].completion(.success(.empty))
        environment.connections[1].pendingRequests[1].completion(.failure(.internal(debugDescription: "nope")))
        try await requireEventually { results == [true, false] }

        // Transfers to the Apple keychain aren't implemented and never answer.
        viewModel.transfer(Self.credential("home"), to: .Apple) { results.append($0) }
        #expect(results.count == 2)
    }

    @Test func deletingReloadsTheCredentials() async throws {
        let environment = Environment()
        defer { environment.restore() }
        environment.client.credentials = [Self.credential("home")]
        let viewModel = ThreadCredentialsManagementViewModel()

        viewModel.deleteCredential(nil)
        #expect(environment.client.deleted.isEmpty)

        viewModel.deleteCredential(Self.credential("home"))
        #expect(environment.client.deleted == ["mac-home"])
        try await requireEventually { viewModel.configs.count == 1 }
    }

    // MARK: - Sharing view models

    @Test func keychainSharingSucceedsOrExplainsTheFailure() async {
        let environment = Environment()
        defer { environment.restore() }

        let viewModel = ThreadTransferCredentialToKeychainViewModel(
            macExtendedAddress: "mac",
            activeOperationalDataset: "tlv"
        )
        await viewModel.mainOperation()
        #expect(viewModel.showOperationSuccess)
        #expect(environment.client.saved == ["tlv"])

        environment.client.saveError = ThreadClientServiceError.failedToConvertToHexadecimal
        let hexFailure = ThreadTransferCredentialToKeychainViewModel(
            macExtendedAddress: "m",
            activeOperationalDataset: "x"
        )
        await hexFailure.mainOperation()
        #expect(hexFailure.showAlert)
        if case .error = hexFailure.alertType {} else { Issue.record("expected an error alert") }

        environment.client.saveError = TestError.failed
        let otherFailure = ThreadTransferCredentialToKeychainViewModel(
            macExtendedAddress: "m",
            activeOperationalDataset: "x"
        )
        await otherFailure.mainOperation()
        #expect(otherFailure.showAlert)
        #expect(!otherFailure.showOperationSuccess)
    }

    @Test func homeAssistantSharingImportsEveryCredentialInTurn() async throws {
        let environment = Environment()
        defer { environment.restore() }
        let connection = environment.connections[0]
        let server = environment.servers.all[0]

        environment.client.credentials = []
        let empty = ThreadTransferCredentialToHAViewModel(server: server, threadClient: environment.client)
        await empty.mainOperation()
        #expect(empty.showAlert)
        if case .empty = empty.alertType {} else { Issue.record("expected the empty alert") }

        environment.client.retrieveError = TestError.failed
        let failing = ThreadTransferCredentialToHAViewModel(server: server, threadClient: environment.client)
        await failing.mainOperation()
        if case .error = failing.alertType {} else { Issue.record("expected an error alert") }
        environment.client.retrieveError = nil

        environment.client.credentials = [Self.credential("a"), Self.credential("b")]
        let importing = ThreadTransferCredentialToHAViewModel(server: server, threadClient: environment.client)
        await importing.mainOperation()
        try await requireEventually { connection.pendingRequests.count == 1 }
        connection.pendingRequests[0].completion(.success(.empty))
        try await requireEventually { connection.pendingRequests.count == 2 }
        connection.pendingRequests[1].completion(.success(.empty))
        try await requireEventually { importing.showOperationSuccess }

        let rejected = ThreadTransferCredentialToHAViewModel(server: server, threadClient: environment.client)
        await rejected.mainOperation()
        try await requireEventually { connection.pendingRequests.count == 3 }
        connection.pendingRequests[2].completion(.failure(.internal(debugDescription: "no")))
        try await requireEventually { rejected.showAlert }
        #expect(!rejected.showOperationSuccess)
    }

    // MARK: - Views

    @Test func managementScreenRendersLoadedCredentials() async {
        let environment = Environment()
        defer { environment.restore() }
        environment.client.credentials = [Self.credential("home")]
        await render(NavigationStack { ThreadCredentialsManagementView() })

        let viewModel = ThreadCredentialsManagementViewModel()
        await viewModel.loadCredentials()
        for source in [HAThreadNetworkConfig.Source.Apple, .HomeAssistant] {
            await render(
                ThreadCredentialDetailsView(source: source, credential: Self.credential("home"))
                    .environmentObject(viewModel)
            )
        }
        #expect(viewModel.configs.count == 1)
    }

    @Test func sharingScreenRendersEachOutcome() async {
        let environment = Environment()
        defer { environment.restore() }

        let success = ThreadTransferCredentialToKeychainViewModel(
            macExtendedAddress: "m",
            activeOperationalDataset: "x"
        )
        success.showOperationSuccess = true
        await render(ThreadCredentialsSharingView(viewModel: success))

        environment.client.saveError = TestError.failed
        let failure = ThreadTransferCredentialToKeychainViewModel(
            macExtendedAddress: "m",
            activeOperationalDataset: "x"
        )
        await render(ThreadCredentialsSharingView(viewModel: failure)) {
            _ = await waitUntil { failure.showAlert }
        }
        #expect(failure.showAlert)

        environment.client.credentials = []
        let empty = ThreadTransferCredentialToHAViewModel(
            server: environment.servers.all[0],
            threadClient: environment.client
        )
        await render(ThreadCredentialsSharingView(viewModel: empty)) {
            _ = await waitUntil { empty.showAlert }
        }
        #expect(empty.showAlert)
    }
}
