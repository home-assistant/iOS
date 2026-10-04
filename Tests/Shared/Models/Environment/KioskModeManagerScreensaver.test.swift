import Combine
import GRDB
@testable import Shared
import XCTest

@MainActor
final class KioskModeManagerScreensaverTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var cancellables = Set<AnyCancellable>()

    override func setUpWithError() throws {
        try super.setUpWithError()
        let database = try DatabaseQueue(path: ":memory:")
        try KioskSettingsTable().createIfNeeded(database: database)
        self.database = database
        previousDatabase = Current.database
        Current.database = { database }
    }

    override func tearDown() {
        cancellables.removeAll()
        Current.database = previousDatabase
        super.tearDown()
    }

    func testScreensaverModeAndDimLevelArePersisted() throws {
        let manager = KioskModeManager()
        XCTAssertFalse(manager.shouldKeepScreenOn)

        manager.setScreensaverMode(.blank)
        manager.setScreensaverDimLevel(1.7)

        var stored = try XCTUnwrap(database.read { try KioskSettings.fetchOne($0) })
        XCTAssertEqual(stored.screensaver.mode, .blank)
        XCTAssertEqual(stored.screensaver.dimLevel, 1)

        manager.setScreensaverDimLevel(-0.5)
        stored = try XCTUnwrap(database.read { try KioskSettings.fetchOne($0) })
        XCTAssertEqual(stored.screensaver.dimLevel, 0)

        manager.setScreensaverMode(.dim)
        manager.setScreensaverDimLevel(0.4)
        stored = try XCTUnwrap(database.read { try KioskSettings.fetchOne($0) })
        XCTAssertEqual(stored.screensaver.mode, .dim)
        XCTAssertEqual(stored.screensaver.dimLevel, 0.4)
    }

    func testWritesWithoutATableAreLoggedRatherThanThrown() throws {
        let manager = KioskModeManager()
        let emptyDatabase = try DatabaseQueue(path: ":memory:")
        Current.database = { emptyDatabase }

        manager.setScreensaverMode(.clock)
        manager.setScreensaverDimLevel(0.5)

        let tableExists = try emptyDatabase.read { try $0.tableExists(GRDBDatabaseTable.kioskSettings.rawValue) }
        XCTAssertFalse(tableExists)
    }

    func testPublishersReflectRequestsAndVisibility() {
        let manager = KioskModeManager()
        var commands = [KioskScreensaverCommand]()
        var overlayValues = [Bool]()
        var screensaverValues = [Bool]()
        var settingsValues = [KioskSettings]()

        manager.screensaverCommandPublisher.sink { commands.append($0) }.store(in: &cancellables)
        manager.cameraOverlayVisiblePublisher.sink { overlayValues.append($0) }.store(in: &cancellables)
        manager.screensaverVisiblePublisher.sink { screensaverValues.append($0) }.store(in: &cancellables)
        manager.settingsPublisher.sink { settingsValues.append($0) }.store(in: &cancellables)

        manager.requestScreensaver(.show)
        manager.requestScreensaver(.hide)
        manager.setCameraOverlayVisible(true)
        manager.setScreensaverVisible(true)
        manager.setScreensaverVisible(false)

        XCTAssertEqual(commands, [.show, .hide])
        XCTAssertEqual(overlayValues, [false, true])
        XCTAssertEqual(screensaverValues, [false, true, false])
        XCTAssertTrue(manager.isCameraOverlayVisible)
        XCTAssertFalse(manager.isScreensaverVisible)
        XCTAssertEqual(settingsValues.first, manager.settings)
    }
}
