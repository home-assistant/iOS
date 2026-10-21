import Combine
import Foundation
import HAKit
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class OnboardingAuthTests: XCTestCase {
    private var auth: OnboardingAuth!
    private var instance: DiscoveredHomeAssistant!
    private var previousCurrentNetworkState: (() async -> NetworkState)!
    private var presenter: OnboardingAuthPresenter!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()

        auth = OnboardingAuth()
        previousCurrentNetworkState = Current.connectivity.currentNetworkState

        Current.servers = FakeServerManager()
        presenter = OnboardingAuthPresenter()
        cancellables.removeAll()

        var instance = DiscoveredHomeAssistant(manualURL: URL(string: "https://external.homeassistant:8123")!)
        instance.internalURL = URL(string: "https://internal.homeassistant:8123")!
        self.instance = instance
    }

    override func tearDown() {
        Current.connectivity.currentNetworkState = previousCurrentNetworkState
        FakeOnboardingAuthPostStepBeforeRegister1.onPerform = nil
        FakeOnboardingAuthPostStepAfterRegister1.onPerform = nil
        cancellables.removeAll()

        super.tearDown()
    }

    func testPlainSetup() {
        // ObjectIdentifier makes contains easier
        let pre = auth.preSteps.map(ObjectIdentifier.init)
        let post = auth.postSteps.map(ObjectIdentifier.init)

        // normally it is bad to tautologically test that some lines exist in the non-test code
        // however, auth is important enough that removing a step should be _very_ intentional
        XCTAssertTrue(auth.login is OnboardingAuthLoginImpl)
        XCTAssertTrue(auth.tokenExchange is OnboardingAuthTokenExchangeImpl)

        XCTAssertTrue(pre.contains(.init(OnboardingAuthStepConnectivity.self)))

        XCTAssertTrue(post.contains(.init(OnboardingAuthStepDeviceNaming.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepConfig.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepSensors.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepModels.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepRegister.self)))
        XCTAssertTrue(post.contains(.init(OnboardingAuthStepNotify.self)))
    }

    func testBeforeAuthFails() throws {
        let result = auth(preBeforeAuth: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertTrue(Current.servers.all.isEmpty)
    }

    func testLoginFails() throws {
        let result = auth(
            internalLoginResult: .init(error: TestError.specific),
            externalLoginResult: .init(error: TestError.any)
        )
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertTrue(Current.servers.all.isEmpty)
    }

    func testTokenFails() throws {
        let result = auth(tokenResult: .init(error: TestError.specific))
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertTrue(Current.servers.all.isEmpty)
    }

    func testBeforeRegisterFails() throws {
        let result = auth(postBeforeRegister: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertTrue(Current.servers.all.isEmpty)
    }

    func testRegisterFails() throws {
        let result = auth(postRegister: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertTrue(Current.servers.all.isEmpty)
    }

    func testAfterRegisterFails() throws {
        let result = auth(postAfterRegister: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertTrue(Current.servers.all.isEmpty)
    }

    func testCompleteFails() throws {
        let result = auth(postComplete: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertTrue(Current.servers.all.isEmpty)
    }

    func testServerIdentityUsesReportedInstanceID() {
        let info = with(ServerInfo.fake()) { $0.instanceID = "instance-1" }

        let identity = OnboardingAuth.serverIdentity(
            for: info,
            fallback: "fallback-identifier",
            existingServers: []
        )

        XCTAssertEqual(identity, .new("instance-1"))
    }

    func testServerIdentityFallsBackWhenNoInstanceIDIsReported() {
        let unreported = ServerInfo.fake()
        let empty = with(ServerInfo.fake()) { $0.instanceID = "" }

        XCTAssertEqual(
            OnboardingAuth.serverIdentity(for: unreported, fallback: "fallback-identifier", existingServers: []),
            .new("fallback-identifier")
        )
        XCTAssertEqual(
            OnboardingAuth.serverIdentity(for: empty, fallback: "fallback-identifier", existingServers: []),
            .new("fallback-identifier")
        )
    }

    /// Re-onboarding a server the app already has must not rename it: widgets, shortcuts and Siri
    /// configurations hold the existing identifier in stores this app cannot rewrite.
    func testServerIdentityKeepsTheIdentifierOfTheSameInstanceAtTheSameAddress() {
        let existing = Server.fake(identifier: "server-from-an-older-install") {
            $0.instanceID = "instance-1"
        }
        let info = with(ServerInfo.fake()) { $0.instanceID = "instance-1" }

        let identity = OnboardingAuth.serverIdentity(
            for: info,
            fallback: "fallback-identifier",
            existingServers: [existing]
        )

        XCTAssertEqual(identity, .existing("server-from-an-older-install"))
    }

    /// The scheme does not tell two servers apart: reaching the same socket over `https` where the
    /// stored server has `http` is still that server.
    func testServerIdentityMatchesTheSameHostAndPortOnAnotherScheme() {
        let existing = Server.fake(identifier: "existing", initial: info(
            instanceID: "instance-1",
            internalURL: URL(string: "http://homeassistant.local:8123")
        ))
        let onboarded = info(instanceID: "instance-1", internalURL: URL(string: "https://homeassistant.local:8123"))

        XCTAssertEqual(
            OnboardingAuth.serverIdentity(for: onboarded, fallback: "fallback", existingServers: [existing]),
            .existing("existing")
        )
    }

    /// A server set up from another one's backup reports that one's ID from somewhere else entirely,
    /// so the ID alone is not enough to call them the same.
    func testServerIdentityIsAmbiguousForTheSameInstanceIDAtAnotherAddress() {
        let existing = Server.fake(identifier: "fbd295e9", initial: info(
            instanceID: "fbd295e9",
            internalURL: URL(string: "http://homeassistant.local:8123")
        ))
        let onboarded = info(instanceID: "fbd295e9", externalURL: URL(string: "http://chalet.duckdns.org:8123"))

        XCTAssertEqual(
            OnboardingAuth.serverIdentity(for: onboarded, fallback: "autogenerated-1", existingServers: [existing]),
            .ambiguous(existing: existing, separateIdentifier: "autogenerated-1")
        )
    }

    /// Kept apart, the new server must never land on an identifier another server already uses.
    func testServerIdentityMintsASeparateIdentifierWhenTheFallbackIsTaken() throws {
        let existing = Server.fake(identifier: "taken", initial: info(
            instanceID: "instance-1",
            internalURL: URL(string: "http://homeassistant.local:8123")
        ))
        let onboarded = info(instanceID: "instance-1", internalURL: URL(string: "http://elsewhere.local:8123"))

        let identity = OnboardingAuth.serverIdentity(for: onboarded, fallback: "taken", existingServers: [existing])

        guard case let .ambiguous(match, separateIdentifier) = identity else {
            return XCTFail("expected an ambiguous identity, got \(identity)")
        }
        XCTAssertEqual(match, existing)
        XCTAssertNotEqual(separateIdentifier, "taken")
        XCTAssertNotEqual(separateIdentifier, "instance-1")
    }

    /// A server the app knows by address that now reports an ID nobody has regenerated its ID, and
    /// is updated in place rather than added a second time.
    func testServerIdentityAdoptsANewInstanceIDAtAKnownAddress() {
        let existing = Server.fake(identifier: "existing", initial: info(
            instanceID: "old-instance",
            internalURL: URL(string: "http://homeassistant.local:8123")
        ))
        let onboarded = info(instanceID: "new-instance", internalURL: URL(string: "http://homeassistant.local:8123"))

        XCTAssertEqual(
            OnboardingAuth.serverIdentity(for: onboarded, fallback: "fallback", existingServers: [existing]),
            .existing("existing")
        )
    }

    /// An instance ID that happens to be the identifier of an unrelated server is not reused.
    func testServerIdentityAvoidsAnInstanceIDAnotherServerIsStoredUnder() {
        let unrelated = Server.fake(identifier: "instance-1", initial: info(
            instanceID: "other-instance",
            internalURL: URL(string: "http://other.local:8123")
        ))
        let onboarded = info(instanceID: "instance-1", internalURL: URL(string: "http://homeassistant.local:8123"))

        XCTAssertEqual(
            OnboardingAuth.serverIdentity(for: onboarded, fallback: "fallback", existingServers: [unrelated]),
            .new("fallback")
        )
    }

    func testSameInstanceIDAtAnotherAddressAsksAndAddsASeparateServer() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }
        let existing = addExistingServer(instanceID: "fbd295e9")
        let prompt = answerServerIdentity { $0.addAsSeparateServer() }
        reportInstanceID("fbd295e9")

        let server = try hang(authWithServerIdentityStep())
        wait(for: [prompt], timeout: 10.0)

        XCTAssertEqual(Current.servers.all.count, 2)
        XCTAssertNotEqual(server.identifier, existing.identifier)
        XCTAssertEqual(server.identifier.rawValue, instance.uuid)
        XCTAssertEqual(server.info.instanceID, "fbd295e9")
        XCTAssertEqual(Current.servers.server(for: existing.identifier)?.info, existing.info)
    }

    func testSameInstanceIDAtAnotherAddressAsksAndReplacesTheExistingServer() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }
        let existing = addExistingServer(instanceID: "fbd295e9")
        let prompt = answerServerIdentity { $0.replaceExistingServer() }
        reportInstanceID("fbd295e9")

        let server = try hang(authWithServerIdentityStep())
        wait(for: [prompt], timeout: 10.0)

        XCTAssertEqual(Current.servers.all.count, 1)
        XCTAssertEqual(server.identifier, existing.identifier)
        XCTAssertEqual(server.info.connection.address(for: .internal), instance.internalURL)
    }

    func testSameInstanceIDAtAnotherAddressCancelledKeepsTheExistingServerUntouched() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }
        let existing = addExistingServer(instanceID: "fbd295e9")
        let existingInfo = existing.info
        let prompt = answerServerIdentity { $0.cancel() }
        reportInstanceID("fbd295e9")

        XCTAssertThrowsError(try hang(authWithServerIdentityStep())) { error in
            guard case PMKError.cancelled = error else {
                return XCTFail("expected a cancellation, got \(error)")
            }
        }
        wait(for: [prompt], timeout: 10.0)

        XCTAssertEqual(Current.servers.all.map(\.identifier), [existing.identifier])
        XCTAssertEqual(Current.servers.server(for: existing.identifier)?.info, existingInfo)
    }

    func testSameInstanceIDAtTheSameHostOnAnotherSchemeUpdatesInPlaceWithoutAsking() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }
        let existing = addExistingServer(
            instanceID: "instance-1",
            internalURL: URL(string: "http://internal.homeassistant:8123")
        )
        presenter.$serverIdentityRequest
            .compactMap { $0 }
            .sink { _ in XCTFail("the same server must not be asked about") }
            .store(in: &cancellables)
        reportInstanceID("instance-1")

        let server = try hang(authWithServerIdentityStep())

        XCTAssertEqual(Current.servers.all.count, 1)
        XCTAssertEqual(server.identifier, existing.identifier)
        XCTAssertEqual(server.info.connection.address(for: .internal), instance.internalURL)
    }

    func testFailureAfterOverwritingAnExistingServerRestoresIt() throws {
        let uuid = try XCTUnwrap(instance.uuid)
        let identifier = Identifier<Server>(rawValue: uuid)
        let existingInfo = with(ServerInfo.fake()) {
            $0.remoteName = "Server from before onboarding"
            $0.instanceID = "instance-1"
        }
        Current.servers.add(identifier: identifier, serverInfo: existingInfo)

        let result = auth(postComplete: [.value(()), .init(error: TestError.specific)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .specific)
        }

        XCTAssertEqual(Current.servers.all.count, 1)
        XCTAssertEqual(Current.servers.server(for: identifier)?.info, existingInfo)
    }

    func testFailureBeforeAnythingIsPersistedKeepsAnExistingServer() throws {
        let uuid = try XCTUnwrap(instance.uuid)
        let identifier = Identifier<Server>(rawValue: uuid)
        let existingInfo = with(ServerInfo.fake()) {
            $0.remoteName = "Server from before onboarding"
        }
        Current.servers.add(identifier: identifier, serverInfo: existingInfo)

        let result = auth(postBeforeRegister: [.value(()), .init(error: TestError.cancelled)])
        XCTAssertThrowsError(try hang(result))

        XCTAssertEqual(Current.servers.server(for: identifier)?.info, existingInfo)
    }

    func testFailureBeforeAnythingIsPersistedKeepsTheExistingServersAPI() throws {
        let identifier = try Identifier<Server>(rawValue: XCTUnwrap(instance.uuid))
        Current.servers.add(identifier: identifier, serverInfo: .fake())
        let existingAPI = try HomeAssistantAPI(server: XCTUnwrap(Current.servers.server(for: identifier)))
        Current.setCachedApi(existingAPI, for: identifier)

        let result = auth(postBeforeRegister: [.value(()), .init(error: TestError.cancelled)])
        XCTAssertThrowsError(try hang(result))

        XCTAssertTrue(Current.cachedApis[identifier] === existingAPI)
    }

    func testFailureBeforeAnythingIsPersistedDropsTheUnsavedServersAPI() throws {
        var unsavedServer: Server?
        FakeOnboardingAuthPostStepBeforeRegister1.onPerform = { api in
            unsavedServer = api.server
            _ = Current.api(for: api.server)
        }

        let result = auth(postBeforeRegister: [.init(error: TestError.cancelled), .value(()), .value(())])
        XCTAssertThrowsError(try hang(result))

        let server = try XCTUnwrap(unsavedServer)
        XCTAssertNil(Current.cachedApis[server.identifier])
    }

    /// A server added next to an existing one is asked what it should receive at the end of
    /// onboarding, so it must not be handed this device's location or the sensors the user switched
    /// on for another one on its way through registration.
    func testAdditionalServerIsOnboardedSendingNothing() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }
        Current.servers.add(
            identifier: "a-server-from-before",
            serverInfo: with(ServerInfo.fake()) { $0.instanceID = "another-instance" }
        )

        let server = try hang(auth())

        XCTAssertEqual(server.info.setting(for: .sensorPrivacy), ServerSensorPrivacy.none)
        XCTAssertEqual(server.info.setting(for: .locationPrivacy), ServerLocationPrivacy.never)
    }

    /// The app's first server answers the same questions through the location permission screen and
    /// starts with nothing switched on, so it keeps the defaults.
    func testFirstServerIsOnboardedWithTheDefaultPrivacySettings() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }

        let server = try hang(auth())

        XCTAssertEqual(server.info.setting(for: .sensorPrivacy), ServerSensorPrivacy.all)
        XCTAssertEqual(server.info.setting(for: .locationPrivacy), ServerLocationPrivacy.exact)
    }

    /// Re-authenticating is not a new server and shows no privacy step, so the choices the server
    /// already carries survive it rather than being reset to the holdback above.
    func testReauthenticatingAServerKeepsItsPrivacySettings() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }
        let uuid = try XCTUnwrap(instance.uuid)
        let identifier = Identifier<Server>(rawValue: uuid)
        Current.servers.add(
            identifier: identifier,
            serverInfo: with(ServerInfo.fake()) {
                $0.setSetting(value: ServerSensorPrivacy.all, for: .sensorPrivacy)
                $0.setSetting(value: ServerLocationPrivacy.zoneOnly, for: .locationPrivacy)
            }
        )

        let server = try hang(auth())

        XCTAssertEqual(server.identifier, identifier)
        XCTAssertEqual(server.info.setting(for: .sensorPrivacy), ServerSensorPrivacy.all)
        XCTAssertEqual(server.info.setting(for: .locationPrivacy), ServerLocationPrivacy.zoneOnly)
    }

    func testCancelledLogin() throws {
        let result = auth(
            includeExternal: false, // cancelled should not attempt external
            internalLoginResult: .init(error: TestError.cancelled)
        )
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .cancelled)
        }

        XCTAssertTrue(Current.servers.all.isEmpty)
    }

    func testCancelledBefore() throws {
        let result = auth(postBeforeRegister: [.value(()), .init(error: TestError.cancelled)])
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .cancelled)
        }

        XCTAssertTrue(Current.servers.all.isEmpty)
    }

    func testSuccessfulWithInternalAndExternalAndInternalSucceedsWithoutSSID() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }

        let result = auth()
        let server = try hang(result)
        // test api state
        // add tests above to test negated api state

        let tokenInfo = server.info.token
        XCTAssertEqual(tokenInfo.accessToken, "access_token1")
        XCTAssertEqual(tokenInfo.refreshToken, "refresh_token1")

        let connectionInfo = server.info.connection
        XCTAssertEqual(connectionInfo.address(for: .internal), instance.internalURL)
        XCTAssertEqual(connectionInfo.address(for: .external), instance.externalURL)
        XCTAssertEqual(connectionInfo.overrideActiveURLType, .internal)

        XCTAssertEqual(Current.servers.server(for: server.identifier)?.info, server.info)
    }

    func testSuccessfulWithInternalAndExternalAndInternalSucceedsDoesNotRecordCurrentSSID() throws {
        Current.connectivity.currentNetworkState = {
            NetworkState(ssid: "unit_test", hardwareAddress: "unit_test_addr")
        }

        let result = auth()
        let server = try hang(result)
        // test api state
        // add tests above to test negated api state

        let tokenInfo = server.info.token
        XCTAssertEqual(tokenInfo.accessToken, "access_token1")
        XCTAssertEqual(tokenInfo.refreshToken, "refresh_token1")

        let connectionInfo = server.info.connection
        XCTAssertEqual(connectionInfo.address(for: .internal), instance.internalURL)
        XCTAssertEqual(connectionInfo.address(for: .external), instance.externalURL)
        XCTAssertNil(connectionInfo.internalSSIDs)
        XCTAssertNil(connectionInfo.internalHardwareAddresses)
        XCTAssertEqual(connectionInfo.overrideActiveURLType, .internal)

        XCTAssertEqual(Current.servers.server(for: server.identifier)?.info, server.info)
    }

    func testSuccessfulWithInternalAndExternalAndInternalFails() throws {
        let result = auth(internalLoginResult: .init(error: TestError.specific))
        let server = try hang(result)
        // test api state
        // add tests above to test negated api state

        let tokenInfo = server.info.token
        XCTAssertEqual(tokenInfo.accessToken, "access_token1")
        XCTAssertEqual(tokenInfo.refreshToken, "refresh_token1")

        let connectionInfo = server.info.connection
        XCTAssertNil(connectionInfo.address(for: .internal))
        XCTAssertEqual(connectionInfo.address(for: .external), instance.externalURL)
        XCTAssertNil(connectionInfo.overrideActiveURLType)
        XCTAssertTrue(connectionInfo.useCloud)

        XCTAssertEqual(Current.servers.server(for: server.identifier)?.info, server.info)
    }

    func testSuccessfulWithOnlyExternal() throws {
        instance.internalURL = nil

        let result = auth()
        let server = try hang(result)
        // test api state
        // add tests above to test negated api state

        let tokenInfo = server.info.token
        XCTAssertEqual(tokenInfo.accessToken, "access_token1")
        XCTAssertEqual(tokenInfo.refreshToken, "refresh_token1")

        let connectionInfo = server.info.connection
        XCTAssertNil(connectionInfo.address(for: .internal))
        XCTAssertEqual(connectionInfo.address(for: .external), instance.externalURL)
        XCTAssertNil(connectionInfo.overrideActiveURLType)
        XCTAssertTrue(connectionInfo.useCloud)

        XCTAssertEqual(Current.servers.server(for: server.identifier)?.info, server.info)
    }

    func testSuccessfulWithOnlyExternalDoesNotRecordCurrentSSID() throws {
        instance.internalURL = nil
        Current.connectivity.currentNetworkState = {
            NetworkState(ssid: "unit_test", hardwareAddress: "unit_test_addr")
        }

        let server = try hang(auth())

        let connectionInfo = server.info.connection
        XCTAssertNil(connectionInfo.internalSSIDs)
        XCTAssertNil(connectionInfo.internalHardwareAddresses)
        XCTAssertNil(connectionInfo.overrideActiveURLType)
    }

    func testSuccessfulWithInternalAndExternalAndInternalFailsDoesNotRecordCurrentSSID() throws {
        Current.connectivity.currentNetworkState = {
            NetworkState(ssid: "unit_test", hardwareAddress: "unit_test_addr")
        }

        let server = try hang(auth(internalLoginResult: .init(error: TestError.specific)))

        let connectionInfo = server.info.connection
        XCTAssertNil(connectionInfo.address(for: .internal))
        XCTAssertNil(connectionInfo.internalSSIDs)
        XCTAssertNil(connectionInfo.internalHardwareAddresses)
        XCTAssertNil(connectionInfo.overrideActiveURLType)
    }

    func testInternalPortRedirectIsAdopted() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }

        // Login web view ended up on a different port than the URL we started the internal attempt with.
        let result = auth(
            internalLoginResult: .value(.init(
                code: "code1",
                resolvedURL: URL(string: "https://internal.homeassistant:8124")
            ))
        )
        let server = try hang(result)

        let connectionInfo = server.info.connection
        // internal URL adopts the redirected port; external is left untouched
        XCTAssertEqual(connectionInfo.address(for: .internal), URL(string: "https://internal.homeassistant:8124"))
        XCTAssertEqual(connectionInfo.address(for: .external), instance.externalURL)
    }

    func testHostChangeDuringLoginIsNotAdopted() throws {
        Current.connectivity.currentNetworkState = { NetworkState() }

        // Different host should never be adopted; keep the original internal URL.
        let result = auth(
            internalLoginResult: .value(.init(
                code: "code1",
                resolvedURL: URL(string: "https://different.homeassistant:8124")
            ))
        )
        let server = try hang(result)

        let connectionInfo = server.info.connection
        XCTAssertEqual(connectionInfo.address(for: .internal), instance.internalURL)
        XCTAssertEqual(connectionInfo.address(for: .external), instance.externalURL)
    }

    func testInstanceAdoptingResolvedURL() throws {
        var instance = DiscoveredHomeAssistant(manualURL: URL(string: "https://external.homeassistant:8123")!)
        instance.internalURL = URL(string: "https://internal.homeassistant:8123")!
        let attempted = try XCTUnwrap(instance.internalURL)

        // nil resolved → unchanged
        XCTAssertEqual(
            OnboardingAuth.instance(instance, adoptingResolvedURL: nil, attemptedURL: attempted),
            instance
        )

        // identical base → unchanged
        XCTAssertEqual(
            OnboardingAuth.instance(
                instance,
                adoptingResolvedURL: URL(string: "https://internal.homeassistant:8123/auth/authorize?x=1"),
                attemptedURL: attempted
            ),
            instance
        )

        // port change on the matching slot → adopted, other slot untouched
        let portChanged = OnboardingAuth.instance(
            instance,
            adoptingResolvedURL: URL(string: "https://internal.homeassistant:8124/auth/authorize"),
            attemptedURL: attempted
        )
        XCTAssertEqual(portChanged.internalURL, URL(string: "https://internal.homeassistant:8124"))
        XCTAssertEqual(portChanged.externalURL, instance.externalURL)

        // https->http downgrade → NOT adopted (transport must not be downgraded)
        let downgraded = OnboardingAuth.instance(
            instance,
            adoptingResolvedURL: URL(string: "http://internal.homeassistant:8123"),
            attemptedURL: attempted
        )
        XCTAssertEqual(downgraded.internalURL, instance.internalURL)

        // http->https upgrade → adopted
        var httpInstance = DiscoveredHomeAssistant(manualURL: URL(string: "https://external.homeassistant:8123")!)
        httpInstance.internalURL = URL(string: "http://internal.homeassistant:8123")!
        let httpAttempted = try XCTUnwrap(httpInstance.internalURL)
        let upgraded = OnboardingAuth.instance(
            httpInstance,
            adoptingResolvedURL: URL(string: "https://internal.homeassistant:8123"),
            attemptedURL: httpAttempted
        )
        XCTAssertEqual(upgraded.internalURL, URL(string: "https://internal.homeassistant:8123"))

        // different host → ignored
        XCTAssertEqual(
            OnboardingAuth.instance(
                instance,
                adoptingResolvedURL: URL(string: "https://elsewhere.homeassistant:8124"),
                attemptedURL: attempted
            ),
            instance
        )
    }

    func testOrderPostCommands() throws {
        let postBefore1 = Promise<Void>.pending()
        let postRegister1 = Promise<Void>.pending()
        let postAfter1 = Promise<Void>.pending()
        let postComplete1 = Promise<Void>.pending()

        let result = auth(
            postBeforeRegister: [postBefore1.promise],
            postRegister: [postRegister1.promise],
            postAfterRegister: [postAfter1.promise],
            postComplete: [postComplete1.promise]
        )

        let expectation1 = expectation(description: "1")
        try XCTUnwrap(FakeOnboardingAuthPostStepBeforeRegister1.wasInvokedPromise).done {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 10.0)

        XCTAssertTrue(FakeOnboardingAuthPostStepBeforeRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepAfterRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepComplete1.wasInvoked)

        postBefore1.resolver.fulfill(())

        let expectation2 = expectation(description: "2")
        try XCTUnwrap(FakeOnboardingAuthPostStepRegister1.wasInvokedPromise).done {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 10.0)

        XCTAssertTrue(FakeOnboardingAuthPostStepBeforeRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepAfterRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepComplete1.wasInvoked)

        postRegister1.resolver.fulfill(())

        let expectation3 = expectation(description: "3")
        try XCTUnwrap(FakeOnboardingAuthPostStepAfterRegister1.wasInvokedPromise).done {
            expectation3.fulfill()
        }
        wait(for: [expectation3], timeout: 10.0)

        XCTAssertTrue(FakeOnboardingAuthPostStepBeforeRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepAfterRegister1.wasInvoked)
        XCTAssertFalse(FakeOnboardingAuthPostStepComplete1.wasInvoked)

        postAfter1.resolver.fulfill(())

        let expectation4 = expectation(description: "4")
        try XCTUnwrap(FakeOnboardingAuthPostStepComplete1.wasInvokedPromise).done {
            expectation4.fulfill()
        }
        wait(for: [expectation4], timeout: 10.0)

        XCTAssertTrue(FakeOnboardingAuthPostStepBeforeRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepAfterRegister1.wasInvoked)
        XCTAssertTrue(FakeOnboardingAuthPostStepComplete1.wasInvoked)

        postComplete1.resolver.fulfill(())

        XCTAssertNoThrow(try hang(result))
    }

    private func info(instanceID: String?, internalURL: URL? = nil, externalURL: URL? = nil) -> ServerInfo {
        with(ServerInfo.fake()) {
            $0.instanceID = instanceID
            $0.connection.set(address: internalURL, for: .internal)
            $0.connection.set(address: externalURL, for: .external)
        }
    }

    @discardableResult
    private func addExistingServer(
        instanceID: String,
        internalURL: URL? = URL(string: "http://homeassistant.local:8123")
    ) -> Server {
        Current.servers.add(
            identifier: "existing-server",
            serverInfo: info(instanceID: instanceID, internalURL: internalURL)
        )
    }

    /// Stands in for `get_config`, which is what fills in the instance ID during `.afterRegister`.
    private func reportInstanceID(_ instanceID: String) {
        FakeOnboardingAuthPostStepAfterRegister1.onPerform = { api in
            api.server.info.instanceID = instanceID
        }
    }

    private func answerServerIdentity(_ answer: @escaping (OnboardingServerIdentityRequest) -> Void)
        -> XCTestExpectation {
        let expectation = expectation(description: "server identity prompt")
        presenter.$serverIdentityRequest
            .compactMap { $0 }
            .first()
            .sink { request in
                DispatchQueue.main.async {
                    answer(request)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        return expectation
    }

    private func authWithServerIdentityStep() -> Promise<Server> {
        auth(extraPostSteps: [OnboardingAuthStepServerIdentity.self])
    }

    private func auth(
        includeInternal: Bool = true,
        includeExternal: Bool = true,
        preBeforeAuth: [Promise<Void>] = [.value(()), .value(()), .value(())],
        internalLoginResult: Promise<OnboardingAuthLoginResult> = .value(.init(code: "code1", resolvedURL: nil)),
        externalLoginResult: Promise<OnboardingAuthLoginResult> = .value(.init(code: "code1", resolvedURL: nil)),
        tokenResult: Promise<TokenInfo> = .value(TokenInfo(
            accessToken: "access_token1",
            refreshToken: "refresh_token1",
            expiration: Date(timeIntervalSinceNow: 1000)
        )),
        postBeforeRegister: [Promise<Void>] = [.value(()), .value(()), .value(())],
        postRegister: [Promise<Void>] = [.value(()), .value(()), .value(())],
        postAfterRegister: [Promise<Void>] = [.value(()), .value(()), .value(())],
        postComplete: [Promise<Void>] = [.value(()), .value(()), .value(())],
        extraPostSteps: [OnboardingAuthPostStep.Type] = []
    ) -> Promise<Server> {
        var preSteps: [OnboardingAuthPreStep.Type] = []
        var postSteps: [OnboardingAuthPostStep.Type] = []

        func combine(types: [(OnboardingAuthPreStep & FakeAuthStepResultable).Type], given: [Promise<Void>]) {
            for (idx, result) in given.enumerated() {
                types[idx].result = result
                types[idx].wasInvoked = false
                preSteps.append(types[idx])
            }
        }

        func combine(types: [(OnboardingAuthPostStep & FakeAuthStepResultable).Type], given: [Promise<Void>]) {
            for (idx, result) in given.enumerated() {
                types[idx].result = result
                types[idx].wasInvoked = false
                postSteps.append(types[idx])
            }
        }

        combine(types: [
            FakeOnboardingAuthPreStepBeforeAuth1.self,
            FakeOnboardingAuthPreStepBeforeAuth2.self,
            FakeOnboardingAuthPreStepBeforeAuth3.self,
        ], given: preBeforeAuth)

        combine(types: [
            FakeOnboardingAuthPostStepBeforeRegister1.self,
            FakeOnboardingAuthPostStepBeforeRegister2.self,
            FakeOnboardingAuthPostStepBeforeRegister3.self,
        ], given: postBeforeRegister)

        combine(types: [
            FakeOnboardingAuthPostStepRegister1.self,
            FakeOnboardingAuthPostStepRegister2.self,
            FakeOnboardingAuthPostStepRegister3.self,
        ], given: postRegister)

        combine(types: [
            FakeOnboardingAuthPostStepAfterRegister1.self,
            FakeOnboardingAuthPostStepAfterRegister2.self,
            FakeOnboardingAuthPostStepAfterRegister3.self,
        ], given: postAfterRegister)

        combine(types: [
            FakeOnboardingAuthPostStepComplete1.self,
            FakeOnboardingAuthPostStepComplete2.self,
            FakeOnboardingAuthPostStepComplete3.self,
        ], given: postComplete)

        auth.preSteps = preSteps
        auth.postSteps = postSteps + extraPostSteps

        var expectedDetails: [OnboardingAuthDetails] = []
        var loginResults: [Promise<OnboardingAuthLoginResult>] = []

        if includeInternal, let internalURL = instance.internalURL {
            expectedDetails.append(try! .init(baseURL: internalURL))
            loginResults.append(internalLoginResult)
        }

        if includeExternal, let externalURL = instance.externalURL {
            expectedDetails.append(try! .init(baseURL: externalURL))
            loginResults.append(externalLoginResult)
        }

        auth.login = FakeOnboardingAuthLogin(
            expectedDetails: expectedDetails,
            results: loginResults
        )
        auth.tokenExchange = FakeOnboardingAuthTokenExchange(
            result: tokenResult,
            expectedCode: internalLoginResult.value?.code ?? externalLoginResult.value?.code
        )

        return auth.authenticate(to: instance, presenter: presenter)
    }
}

private enum TestError: Error, CancellableError {
    case any
    case specific
    case cancelled

    var isCancelled: Bool {
        if case .cancelled = self {
            return true
        } else {
            return false
        }
    }
}

protocol FakeAuthStepResultable {
    static var result: Promise<Void> { get set }
    static var wasInvoked: Bool { get set }
}

class FakeOnboardingAuthLogin: OnboardingAuthLogin {
    func open(
        authDetails: OnboardingAuthDetails,
        presenter: OnboardingAuthPresenter
    ) -> Promise<OnboardingAuthLoginResult> {
        let expected = expectedDetails.removeFirst()
        XCTAssertEqual(authDetails, expected)
        return results.removeFirst()
    }

    var expectedDetails: [OnboardingAuthDetails]
    var results: [Promise<OnboardingAuthLoginResult>]

    init(expectedDetails: [OnboardingAuthDetails?], results: [Promise<OnboardingAuthLoginResult>]) {
        self.expectedDetails = expectedDetails.compactMap { $0 }
        self.results = results
    }
}

struct FakeOnboardingAuthTokenExchange: OnboardingAuthTokenExchange {
    func tokenInfo(code: String, connectionInfo: inout ConnectionInfo) async throws -> TokenInfo {
        XCTAssertEqual(code, expectedCode)
        return try await result.asyncValue()
    }

    var result: Promise<TokenInfo> = .init(error: TestError.any)
    var expectedCode: String?
}

class FakeOnboardingAuthPreStep: OnboardingAuthPreStep {
    var authDetails: OnboardingAuthDetails
    var presenter: OnboardingAuthPresenter
    required init(authDetails: OnboardingAuthDetails, presenter: OnboardingAuthPresenter) {
        self.authDetails = authDetails
        self.presenter = presenter
    }

    class var supportedPoints: Set<OnboardingAuthStepPoint> { fatalError() }
    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> { fatalError() }
}

class FakeOnboardingAuthPreStepBeforeAuth: FakeOnboardingAuthPreStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.beforeAuth]) }
}

class FakeOnboardingAuthPreStepBeforeAuth1: FakeOnboardingAuthPreStepBeforeAuth, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPreStepBeforeAuth2: FakeOnboardingAuthPreStepBeforeAuth, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPreStepBeforeAuth3: FakeOnboardingAuthPreStepBeforeAuth, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStep: OnboardingAuthPostStep {
    class var supportedPoints: Set<OnboardingAuthStepPoint> { fatalError() }

    var api: HomeAssistantAPI
    var presenter: OnboardingAuthPresenter
    required init(api: HomeAssistantAPI, presenter: OnboardingAuthPresenter) {
        self.api = api
        self.presenter = presenter
    }

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> { fatalError() }
}

class FakeOnboardingAuthPostStepBeforeRegister: FakeOnboardingAuthPostStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.beforeRegister]) }
}

class FakeOnboardingAuthPostStepBeforeRegister1: FakeOnboardingAuthPostStepBeforeRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any) {
        didSet {
            (wasInvokedPromise, wasInvokedResolver) = Guarantee<Void>.pending()
        }
    }

    static var wasInvoked: Bool = false {
        didSet {
            if wasInvoked {
                wasInvokedResolver?(())
            }
        }
    }

    static var wasInvokedPromise: Guarantee<Void>?
    static var wasInvokedResolver: ((()) -> Void)?
    static var onPerform: ((HomeAssistantAPI) -> Void)?
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        Self.onPerform?(api)
        return Self.result
    }
}

class FakeOnboardingAuthPostStepBeforeRegister2: FakeOnboardingAuthPostStepBeforeRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepBeforeRegister3: FakeOnboardingAuthPostStepBeforeRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepRegister: FakeOnboardingAuthPostStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.register]) }
}

class FakeOnboardingAuthPostStepRegister1: FakeOnboardingAuthPostStepRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any) {
        didSet {
            (wasInvokedPromise, wasInvokedResolver) = Guarantee<Void>.pending()
        }
    }

    static var wasInvoked: Bool = false {
        didSet {
            if wasInvoked {
                wasInvokedResolver?(())
            }
        }
    }

    static var wasInvokedPromise: Guarantee<Void>?
    static var wasInvokedResolver: ((()) -> Void)?
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepRegister2: FakeOnboardingAuthPostStepRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepRegister3: FakeOnboardingAuthPostStepRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepAfterRegister: FakeOnboardingAuthPostStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.afterRegister]) }
}

class FakeOnboardingAuthPostStepAfterRegister1: FakeOnboardingAuthPostStepAfterRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any) {
        didSet {
            (wasInvokedPromise, wasInvokedResolver) = Guarantee<Void>.pending()
        }
    }

    static var wasInvoked: Bool = false {
        didSet {
            if wasInvoked {
                wasInvokedResolver?(())
            }
        }
    }

    static var wasInvokedPromise: Guarantee<Void>?
    static var wasInvokedResolver: ((()) -> Void)?
    static var onPerform: ((HomeAssistantAPI) -> Void)?
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        Self.onPerform?(api)
        return Self.result
    }
}

class FakeOnboardingAuthPostStepAfterRegister2: FakeOnboardingAuthPostStepAfterRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepAfterRegister3: FakeOnboardingAuthPostStepAfterRegister, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepComplete: FakeOnboardingAuthPostStep {
    override static var supportedPoints: Set<OnboardingAuthStepPoint> { Set([.complete]) }
}

class FakeOnboardingAuthPostStepComplete1: FakeOnboardingAuthPostStepComplete, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any) {
        didSet {
            (wasInvokedPromise, wasInvokedResolver) = Guarantee<Void>.pending()
        }
    }

    static var wasInvoked: Bool = false {
        didSet {
            if wasInvoked {
                wasInvokedResolver?(())
            }
        }
    }

    static var wasInvokedPromise: Guarantee<Void>?
    static var wasInvokedResolver: ((()) -> Void)?
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepComplete2: FakeOnboardingAuthPostStepComplete, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}

class FakeOnboardingAuthPostStepComplete3: FakeOnboardingAuthPostStepComplete, FakeAuthStepResultable {
    static var result: Promise<Void> = .init(error: TestError.any)
    static var wasInvoked: Bool = false
    override func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        Self.wasInvoked = true
        return Self.result
    }
}
