import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The snooze presets screen edits the presets stored in the database, which start as 5, 15 and 60
/// minutes.
final class NotificationSnoozeActionsViewModelTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let database = try DatabaseQueue()
        try NotificationSnoozeActionTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { database }
    }

    override func tearDown() {
        Current.database = previousDatabase
        super.tearDown()
    }

    private func makeLoadedViewModel() -> NotificationSnoozeActionsViewModel {
        let viewModel = NotificationSnoozeActionsViewModel()
        viewModel.load()
        return viewModel
    }

    func testLoadsTheSeededPresets() {
        let viewModel = makeLoadedViewModel()

        XCTAssertEqual(viewModel.actions.map(\.minutes), [5, 15, 60])
        XCTAssertTrue(viewModel.actions.allSatisfy(\.isEnabled))
    }

    func testAddingAppendsAfterTheExistingPresets() {
        let viewModel = makeLoadedViewModel()

        viewModel.add(minutes: 30)

        XCTAssertEqual(viewModel.actions.map(\.minutes), [5, 15, 60, 30])
        XCTAssertEqual(viewModel.actions.last?.sortOrder, 3)
    }

    func testAddingADuplicateDurationIsIgnored() {
        let viewModel = makeLoadedViewModel()

        viewModel.add(minutes: 15)

        XCTAssertEqual(viewModel.actions.map(\.minutes), [5, 15, 60])
    }

    func testDisablingAPresetIsPersisted() {
        let viewModel = makeLoadedViewModel()
        let first = viewModel.actions[0]

        viewModel.setEnabled(false, for: first)

        XCTAssertEqual(viewModel.actions.first(where: { $0.id == first.id })?.isEnabled, false)
        XCTAssertEqual(NotificationSnoozeAction.all().first(where: { $0.id == first.id })?.isEnabled, false)
    }

    func testMovingAPresetPersistsTheNewOrder() {
        let viewModel = makeLoadedViewModel()

        viewModel.move(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(viewModel.actions.map(\.minutes), [15, 60, 5])
        XCTAssertEqual(NotificationSnoozeAction.all().map(\.minutes), [15, 60, 5])
    }

    func testDeletingAPresetRemovesIt() {
        let viewModel = makeLoadedViewModel()

        viewModel.delete(at: IndexSet([0, 2]))

        XCTAssertEqual(viewModel.actions.map(\.minutes), [15])
        XCTAssertEqual(NotificationSnoozeAction.all().map(\.minutes), [15])
    }
}
