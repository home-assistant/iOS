import CoreBluetooth
import CoreLocation
import CoreMotion
import Foundation
import GRDB
import HAKit
@testable import Shared
import UserNotifications
import XCTest

final class AppEnvironmentTests: XCTestCase {
    private var createdIdentifiers: [Identifier<Server>] = []

    override func tearDown() {
        Current.resetAPICache(for: createdIdentifiers)
        createdIdentifiers = []
        super.tearDown()
    }

    func testAppConfigurationDescriptions() {
        XCTAssertEqual(AppConfiguration.allCases, [.fastlaneSnapshot, .debug, .release])
        XCTAssertEqual(AppConfiguration.fastlaneSnapshot.description, "fastlane")
        XCTAssertEqual(AppConfiguration.debug.description, "debug")
        XCTAssertEqual(AppConfiguration.release.description, "release")
    }

    func testBuildFlags() {
        XCTAssertTrue(Current.isRunningTests)
        #if DEBUG
        XCTAssertEqual(Current.apnsEnvironment, "sandbox")
        XCTAssertTrue(Current.isDebug)
        #else
        XCTAssertEqual(Current.apnsEnvironment, "production")
        XCTAssertFalse(Current.isDebug)
        #endif
        XCTAssertEqual(
            AppEnvironment.isTestFlightReceipt(),
            Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        )
    }

    func testAPIIsOnlyBuiltForServersWithAUsableURL() {
        let unreachable = Server.fake { info in
            info.connection.set(address: nil, for: .external)
        }
        createdIdentifiers.append(unreachable.identifier)
        XCTAssertNil(Current.api(for: unreachable))

        let reachable = Server.fake()
        createdIdentifiers.append(reachable.identifier)
        let api = Current.api(for: reachable)
        XCTAssertNotNil(api)
        XCTAssertTrue(Current.api(for: reachable) === api)
        XCTAssertTrue(Current.cachedApis[reachable.identifier] === api)

        Current.resetAPICache(for: [reachable.identifier])
        XCTAssertNil(Current.cachedApis[reachable.identifier])
        XCTAssertFalse(Current.api(for: reachable) === api)
    }

    func testSetCachedApiReplacesTheCachedInstance() {
        let server = Server.fake()
        createdIdentifiers.append(server.identifier)
        let api = HomeAssistantAPI(server: server)

        Current.setCachedApi(api, for: server.identifier)

        XCTAssertTrue(Current.api(for: server) === api)
    }

    func testApisSkipsServersWithoutAUsableURL() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }

        let servers = FakeServerManager()
        let reachable = servers.addFake()
        var unreachableInfo = ServerInfo.fake()
        unreachableInfo.connection.set(address: nil, for: .external)
        let unreachable = servers.add(identifier: .init(rawValue: UUID().uuidString), serverInfo: unreachableInfo)
        createdIdentifiers += [reachable.identifier, unreachable.identifier]
        Current.servers = servers

        let apis = Current.apis

        XCTAssertEqual(apis.count, 1)
        XCTAssertEqual(apis.first?.server, reachable)
    }

    func testDeviceCapabilityWrappersReflectTheSystem() {
        XCTAssertEqual(
            Current.motion.isAuthorized(),
            CMMotionActivityManager.authorizationStatus() == .authorized
        )
        #if targetEnvironment(simulator)
        XCTAssertTrue(Current.motion.isActivityAvailable())
        #endif
        XCTAssertEqual(Current.pedometer.isAuthorized(), CMPedometer.authorizationStatus() == .authorized)
        XCTAssertEqual(Current.pedometer.isStepCountingAvailable(), CMPedometer.isStepCountingAvailable())
        XCTAssertEqual(Current.barometer.isAuthorized(), CMAltimeter.authorizationStatus() == .authorized)
        XCTAssertEqual(Current.barometer.isAvailable(), CMAltimeter.isRelativeAltitudeAvailable())
        XCTAssertEqual(Current.bluetoothPermissionStatus, CBCentralManager.authorization)
        XCTAssertTrue(Current.userNotificationCenter === UNUserNotificationCenter.current())
    }

    func testCoreMotionWrappersAreNeverAuthorizedOnCatalyst() {
        let previous = Current.isCatalyst
        defer { Current.isCatalyst = previous }
        Current.isCatalyst = true

        XCTAssertFalse(Current.motion.isAuthorized())
        XCTAssertFalse(Current.pedometer.isAuthorized())
        XCTAssertFalse(Current.barometer.isAuthorized())
    }

    func testNetworkingEnvironmentReadsTheAppEnvironment() throws {
        let previousDate = Current.date
        let previousIsAppExtension = Current.isAppExtension
        let previousDatabase = Current.database
        defer {
            Current.date = previousDate
            Current.isAppExtension = previousIsAppExtension
            Current.database = previousDatabase
        }

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        Current.date = { fixedDate }
        let database = try DatabaseQueue()
        Current.database = { database }

        let environment = HANetworkingEnvironment.current
        XCTAssertEqual(environment.date(), fixedDate)
        XCTAssertTrue(environment.database() === database)

        Current.isAppExtension = true
        XCTAssertTrue(environment.isAppExtension())
        Current.isAppExtension = false
        XCTAssertFalse(environment.isAppExtension())

        XCTAssertEqual(environment.isDebug, Current.appConfiguration == .debug)
        XCTAssertEqual(environment.bundleID, AppConstants.BundleID)
        XCTAssertEqual(environment.defaultServerName, ServerInfo.defaultName)
        XCTAssertTrue(environment.prefs === Current.settingsStore.prefs)
        XCTAssertEqual(
            environment.connectivity.lastKnownNetworkState(),
            Current.connectivity.lastKnownNetworkState()
        )

        // The log bridge forwards to `Current.Log`; exercising it must not trap.
        environment.log.error("AppEnvironmentTests error")
        environment.log.warning("AppEnvironmentTests warning")
        environment.log.info("AppEnvironmentTests info")
        environment.log.verbose("AppEnvironmentTests verbose")
        environment.log.debug("AppEnvironmentTests debug")
    }

    func testNetworkingEnvironmentRefreshesTheAppDatabaseThroughTheUpdater() {
        let previousUpdater = Current.appDatabaseUpdater
        defer { Current.appDatabaseUpdater = previousUpdater }
        let updater = RecordingDatabaseUpdater()
        Current.appDatabaseUpdater = updater

        let server = Server.fake()
        HANetworkingEnvironment.current.refreshAppDatabase(server, true, false)

        XCTAssertEqual(updater.updates.count, 1)
        XCTAssertEqual(updater.updates.first?.server, server)
        XCTAssertEqual(updater.updates.first?.forceUpdate, true)
        XCTAssertEqual(updater.updates.first?.showProgress, false)
    }

    func testReauthenticationRequiredNotifiesOnboarding() {
        let previousObservation = Current.onboardingObservation
        let previousEventStore = Current.clientEventStore
        let previousModelManager = Current.modelManager
        defer {
            Current.onboardingObservation = previousObservation
            Current.clientEventStore = previousEventStore
            Current.modelManager = previousModelManager
        }

        let observer = RecordingOnboardingObserver()
        Current.onboardingObservation = OnboardingStateObservation()
        Current.onboardingObservation.register(observer: observer)
        var eventTexts = [String]()
        Current.clientEventStore = MockClientEventStore { eventTexts.append($0.text) }
        Current.modelManager = LegacyModelManager()

        let server = Server.fake()
        createdIdentifiers.append(server.identifier)
        let api = HomeAssistantAPI(server: server)
        api.connection = CannedResponseHAConnection()
        Current.setCachedApi(api, for: server.identifier)

        HANetworkingEnvironment.current.handleReauthenticationRequired(server, 401, "invalid refresh token")

        XCTAssertEqual(observer.states, [.needed(.unauthenticated(server.identifier.rawValue, 401))])
        XCTAssertEqual(eventTexts, ["Refresh token is invalid, notifying user"])
    }

    private final class RecordingDatabaseUpdater: AppDatabaseUpdaterProtocol {
        var updates: [(server: Server, forceUpdate: Bool, showProgress: Bool)] = []

        func stop() {}

        func update(server: Server, forceUpdate: Bool, showProgress: Bool) {
            updates.append((server, forceUpdate, showProgress))
        }
    }

    private final class RecordingOnboardingObserver: OnboardingStateObserver {
        var states: [OnboardingState] = []

        func onboardingStateDidChange(to state: OnboardingState) {
            states.append(state)
        }
    }
}
