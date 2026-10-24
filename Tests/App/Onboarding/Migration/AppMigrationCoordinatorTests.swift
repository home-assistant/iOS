import Foundation
import HANetworking
@testable import HomeAssistant
import Security
@testable import Shared
import SnapshotTesting
import Testing

/// Both sides of the hand-off driven in one process: the links one coordinator asks iOS to open are
/// delivered to the other, the way the two apps hand each other control on a device.
@MainActor
struct AppMigrationCoordinatorTests {
    /// Stands in for iOS: records every link a coordinator opens and answers as the test decides.
    final class Opener {
        var opened: [URL] = []
        var answer: @MainActor (URL) async -> Bool = { _ in true }

        var links: [AppMigrationLink] {
            opened.compactMap(AppMigrationLink.init(url:))
        }

        func open(_ url: URL) async -> Bool {
            opened.append(url)
            return await answer(url)
        }
    }

    private static func make(
        role: AppMigrationRole,
        opener: Opener,
        canOpen: Bool = true,
        pacing: TimeInterval = 0,
        releasedPush: (() -> Void)? = nil
    ) -> AppMigrationCoordinator {
        var dependencies = AppMigrationCoordinatorDependencies()
        dependencies.role = role
        dependencies.canOpen = { _ in canOpen }
        dependencies.open = { await opener.open($0) }
        dependencies.pacing = pacing
        dependencies.erasedReadDuration = 0
        dependencies.adoptPushRegistration = {}
        dependencies.releasePushRegistration = { releasedPush?() }
        dependencies.refreshLocalPushManagers = {}
        return AppMigrationCoordinator(dependencies: dependencies)
    }

    private func waitUntil(timeout: Duration = .seconds(20), _ condition: @MainActor () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let start = clock.now
        while clock.now - start < timeout {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    private func expectEventually(
        timeout: Duration = .seconds(20),
        sourceLocation: SourceLocation = #_sourceLocation,
        _ condition: @MainActor () -> Bool
    ) async {
        let satisfied = await waitUntil(timeout: timeout, condition)
        #expect(satisfied, sourceLocation: sourceLocation)
    }

    /// Writes a generic password the way the app's keychain wrapper reads it back.
    private static func store(_ data: Data, service: String, account: String) throws {
        wipe(service: service, account: account)
        let status = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ] as CFDictionary, nil)
        try #require(status == errSecSuccess)
    }

    private static func wipe(service: String, account: String? = nil) {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        SecItemDelete(query as CFDictionary)
    }

    private func reset() {
        AppMigrationHandoffStore.save(nil)
        AppMigrationSessionStore.clear()
        AppMigrationSessionStore.clearCompleted()
        AppMigrationPasteboard.clear()
        HomeAssistantAPI.connectionsSuspended = false
    }

    @Test func theNewAppStartsByAskingThePreviousAppAndCanGiveUp() async {
        reset()
        defer { reset() }
        let opener = Opener()
        let newApp = Self.make(role: .newApp, opener: opener)

        newApp.startImport()
        #expect(newApp.importState == .openingPreviousApp)
        #expect(newApp.keepsScreenOn)
        await expectEventually { opener.opened.count == 1 }
        let session = try? #require(AppMigrationSessionStore.load())
        #expect(opener.links.first == session.map { .request($0) })
        #expect(opener.opened.first?.scheme == AppMigrationRole.previousApp.urlScheme)

        newApp.openPreviousApp()
        await expectEventually { opener.opened.count == 2 }

        newApp.cancelImport()
        #expect(newApp.importState == nil)
        #expect(AppMigrationSessionStore.load() == nil)
        #expect(!newApp.keepsScreenOn)
    }

    @Test func aPreviousAppThatCannotBeOpenedFailsTheImport() async {
        reset()
        defer { reset() }
        let opener = Opener()
        opener.answer = { _ in false }
        let newApp = Self.make(role: .newApp, opener: opener, canOpen: false)
        #expect(!newApp.isPreviousAppInstalled)

        newApp.startImport()
        let expected = AppMigrationImportState
            .failed(message: AppMigrationError.previousAppUnavailable.localizedDescription)
        await expectEventually { newApp.importState == expected }
    }

    @Test func declinesAndStrayLinksAreMatchedToTheSession() async throws {
        reset()
        defer { reset() }
        let opener = Opener()
        let newApp = Self.make(role: .newApp, opener: opener)
        newApp.startImport()
        let session = try #require(AppMigrationSessionStore.load())

        #expect(!newApp.handle(url: AppMigrationLink.declined(sessionID: UUID(), reason: nil).url(to: .newApp)))
        #expect(newApp.handle(url: AppMigrationLink.declined(sessionID: session.id, reason: nil).url(to: .newApp)))
        #expect(newApp.importState == .failed(message: AppMigrationError.declined.localizedDescription))

        let erased = AppMigrationLink.declined(sessionID: session.id, reason: .previousAppErased)
        #expect(newApp.handle(url: erased.url(to: .newApp)))
        #expect(newApp.importState == .failed(message: AppMigrationError.previousAppErased.localizedDescription))

        #expect(!newApp.handle(url: AppMigrationLink.restart(sessionID: UUID()).url(to: .newApp)))
        #expect(!newApp.handle(url: AppMigrationLink.erased(sessionID: UUID()).url(to: .newApp)))
        #expect(newApp.handle(url: AppMigrationLink.payloadReady(sessionID: UUID(), key: nil).url(to: .newApp)))
        #expect(newApp.importState == .failed(message: AppMigrationError.wrongSession.localizedDescription))
        #expect(newApp.handle(url: AppMigrationLink.payloadReady(sessionID: UUID(), key: "short").url(to: .newApp)))
        #expect(newApp.importState == .failed(message: AppMigrationError.wrongSession.localizedDescription))
        #expect(!newApp.handle(url: URL(string: "homeassistant-ohf-dev://settings")!))
        #expect(!newApp.handle(url: AppMigrationLink.request(session).url(to: .previousApp)))

        let completed = UUID()
        AppMigrationSessionStore.saveCompleted(completed)
        #expect(newApp.handle(url: AppMigrationLink.erased(sessionID: completed).url(to: .newApp)))
        #expect(newApp.previousAppErased)
        newApp.finishImport()
        #expect(!newApp.previousAppErased)
        #expect(newApp.completedSummary == nil)

        #expect(newApp.handle(url: AppMigrationLink.restart(sessionID: completed).url(to: .newApp)))
        #expect(newApp.importState == .openingPreviousApp)

        newApp.handle(url: AppMigrationLink.payloadReady(sessionID: session.id, key: nil).url(to: .newApp))
        #expect(newApp.importState == .failed(message: AppMigrationError.wrongSession.localizedDescription))
        newApp.cancelImport()
    }

    @Test func anEmptyOrUnreadablePayloadFailsTheImport() async throws {
        reset()
        defer { reset() }
        let opener = Opener()
        let newApp = Self.make(role: .newApp, opener: opener)
        newApp.startImport()
        let session = try #require(AppMigrationSessionStore.load())

        AppMigrationPasteboard.clear()
        #expect(newApp.handle(url: AppMigrationLink.payloadReady(sessionID: session.id, key: nil).url(to: .newApp)))
        #expect(newApp.importState == .failed(message: AppMigrationError.noPayload.localizedDescription))

        AppMigrationPasteboard.write(Data("not a sealed payload".utf8))
        #expect(newApp.handle(url: AppMigrationLink.payloadReady(sessionID: session.id, key: nil).url(to: .newApp)))
        #expect(newApp.importState == .receiving)
        await expectEventually {
            if case .failed = newApp.importState { return true }
            return false
        }
        #expect(AppMigrationPasteboard.take() == nil)
        newApp.cancelImport()
    }

    @Test func anIdentityThatCannotBeExportedFailsTheTransfer() async {
        reset()
        defer { reset() }
        let previousServers = Current.servers
        let servers = FakeServerManager()
        var secured = ServerInfo.fake()
        secured.connection.clientCertificate = ClientCertificate(
            keychainIdentifier: "missing-identity",
            displayName: "Gone"
        )
        servers.add(identifier: .init(rawValue: UUID().uuidString), serverInfo: secured)
        Current.servers = servers
        defer { Current.servers = previousServers }

        let opener = Opener()
        let previousApp = Self.make(role: .previousApp, opener: opener)
        #expect(previousApp.beginTransferFromThisApp())
        previousApp.transfer()
        await expectEventually {
            if case .failed = previousApp.exportState { return true }
            return false
        }
        #expect(opener.opened.isEmpty)
        previousApp.declineExport()
    }

    @Test func thePreviousAppTakesOverOnRequestAndHandsBackWhenDeclined() async {
        reset()
        defer { reset() }
        let previousServers = Current.servers
        Current.servers = FakeServerManager(initial: 1)
        defer { Current.servers = previousServers }
        let opener = Opener()
        var released = 0
        let previousApp = Self.make(role: .previousApp, opener: opener, releasedPush: { released += 1 })
        let session = AppMigrationSession.make()

        #expect(previousApp.handle(url: AppMigrationLink.request(session).url(to: .previousApp)))
        #expect(previousApp.exportRequest == session)
        #expect(previousApp.handoffPhase == .requested(session, startedHere: false))
        #expect(AppMigrationHandoffStore.isActive)
        #expect(HomeAssistantAPI.connectionsSuspended)
        #expect(previousApp.keepsScreenOn)
        #expect(!previousApp.hasHandedOff)
        #expect(previousApp.exportSummary.serverCount == Current.servers.all.count)
        previousApp.restoreHandoffIfNeeded()
        previousApp.releasePushRegistrationIfHandedOff()
        #expect(released == 0)

        #expect(!previousApp.handle(url: AppMigrationLink.erase(sessionID: session.id).url(to: .previousApp)) == false)
        #expect(previousApp.exportState == .idle)

        previousApp.declineExport()
        await expectEventually { opener.links.contains(.declined(sessionID: session.id, reason: nil)) }
        #expect(previousApp.handoffPhase == nil)
        #expect(previousApp.exportRequest == nil)
        #expect(!HomeAssistantAPI.connectionsSuspended)
        #expect(!previousApp.keepsScreenOn)

        previousApp.openNewApp()
        await expectEventually { opener.opened.last == AppMigrationRole.newApp.baseURL }
    }

    @Test func aTransferFailsWhenTheNewAppDoesNotOpen() async {
        reset()
        defer { reset() }
        let opener = Opener()
        opener.answer = { _ in false }
        let previousApp = Self.make(role: .previousApp, opener: opener, canOpen: false, pacing: 0.2)
        #expect(!previousApp.beginTransferFromThisApp())
        #expect(previousApp.handle(url: AppMigrationLink.request(.make()).url(to: .previousApp)))

        previousApp.transfer()
        #expect(previousApp.exportState == .preparing)
        let failed = AppMigrationExportState.failed(message: AppMigrationError.newAppUnavailable.localizedDescription)
        await expectEventually { previousApp.exportState == failed }
        #expect(AppMigrationPasteboard.take() == nil)
        previousApp.declineExport()
    }

    @Test func aRelaunchRestoresThePersistedPhase() {
        reset()
        defer { reset() }
        let session = AppMigrationSession.make()
        var released = 0

        AppMigrationHandoffStore.save(.requested(session, startedHere: true))
        let requested = Self.make(role: .previousApp, opener: Opener(), releasedPush: { released += 1 })
        #expect(requested.exportRequest == session)
        #expect(requested.keepsScreenOn)

        AppMigrationHandoffStore.save(.handedOff(sessionID: session.id))
        let handedOff = Self.make(role: .previousApp, opener: Opener(), releasedPush: { released += 1 })
        #expect(handedOff.exportState == .handedOff)
        #expect(handedOff.hasHandedOff)
        handedOff.restoreHandoffIfNeeded()
        #expect(HomeAssistantAPI.connectionsSuspended)
        handedOff.releasePushRegistrationIfHandedOff()
        #expect(released == 1)

        AppMigrationHandoffStore.save(.erased(sessionID: session.id))
        let erased = Self.make(role: .previousApp, opener: Opener(), releasedPush: { released += 1 })
        #expect(erased.exportState == .erased)
        #expect(erased.hasHandedOff)
        #expect(!erased.keepsScreenOn)
    }

    @Test func theWholeHandoffRoundTripsIncludingRestartAndErase() async throws {
        reset()
        defer { reset() }
        let previousServers = Current.servers
        let certificate = try ClientCertificateManager.shared.importP12(
            data: TestClientCertificateBundle.data,
            password: TestClientCertificateBundle.password,
            identifier: "round-trip"
        )
        let servers = FakeServerManager(initial: 1)
        var secured = ServerInfo.fake()
        secured.connection.clientCertificate = certificate
        servers.add(identifier: .init(rawValue: UUID().uuidString), serverInfo: secured)
        Current.servers = servers
        defer { Current.servers = previousServers }
        let serversService = AppMigrationKeychainStore.servers.service
        for server in Current.servers.all {
            try Self.store(
                JSONEncoder().encode(server.info),
                service: serversService,
                account: server.identifier.rawValue
            )
        }
        defer { Self.wipe(service: serversService) }

        let previousOpener = Opener()
        let newOpener = Opener()
        var released = 0
        let previousApp = Self.make(role: .previousApp, opener: previousOpener, releasedPush: { released += 1 })
        let newApp = Self.make(role: .newApp, opener: newOpener)
        // On a device each app has its own keychain; here the previous app's wipe would also take the
        // new app's record of the completed session, so it is put back before the link is delivered.
        var completedSession: UUID?
        previousOpener.answer = { url in
            if case .erased = AppMigrationLink(url: url), let completedSession {
                AppMigrationSessionStore.saveCompleted(completedSession)
            }
            return newApp.handle(url: url)
        }
        newOpener.answer = { url in previousApp.handle(url: url) }

        #expect(previousApp.beginTransferFromThisApp())
        guard let request = previousApp.exportRequest else {
            Issue.record("The previous app did not mint a session")
            return
        }
        #expect(previousApp.handoffPhase == .requested(request, startedHere: true))

        previousApp.transfer()
        await expectEventually { newApp.completedSummary != nil }
        #expect(newApp.completedSummary?.serverNames.count == 2)
        #expect(ClientCertificateManager.shared.hasIdentity(for: certificate))
        assertLightDarkSnapshots(
            of: AppMigrationFlowView(coordinator: newApp, skipAction: {}, finishAction: {}),
            named: "new-00c-flow-success"
        )
        #expect(newApp.importState == nil)
        #expect(newApp.keepsScreenOn)
        #expect(previousApp.exportState == .handedOff)
        #expect(previousApp.hasHandedOff)
        #expect(released == 1)
        #expect(AppMigrationSessionStore.loadCompleted() == request.id)
        #expect(AppMigrationPasteboard.take() == nil)

        previousApp.transferAgain()
        await expectEventually { previousApp.handoffPhase != .handedOff(sessionID: request.id) }
        guard case let .requested(again, startedHere) = previousApp.handoffPhase else {
            Issue.record("The previous app did not take the restart")
            return
        }
        #expect(!startedHere)
        #expect(newApp.importState == .openingPreviousApp)

        previousApp.transfer()
        await expectEventually { newApp.completedSummary != nil && previousApp.exportState == .handedOff }
        completedSession = again.id
        #expect(AppMigrationSessionStore.loadCompleted() == again.id)

        newApp.erasePreviousApp()
        await expectEventually { newApp.previousAppErased }
        #expect(previousApp.exportState == .erased)
        #expect(previousApp.handoffPhase == .erased(sessionID: again.id))

        let late = AppMigrationSession.make()
        #expect(previousApp.handle(url: AppMigrationLink.request(late).url(to: .previousApp)))
        await expectEventually {
            previousOpener.links.contains(.declined(sessionID: late.id, reason: .previousAppErased))
        }
        newApp.finishImport()
    }
}
