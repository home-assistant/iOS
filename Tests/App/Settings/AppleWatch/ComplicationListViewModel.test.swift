import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// The legacy complications list: deleting them all reports a database failure, a manual update
/// asks the watch connection, and the watch state is re-read once complications were pushed.
/// Shared state: swaps `Current.database` and posts the complication update notification.
@MainActor
@Suite(.sharedState)
struct ComplicationListViewModelTests {
    @Test func deletingEverythingReportsADatabaseFailure() throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }
        Current.database = { try! DatabaseQueue() }

        let viewModel = ComplicationListViewModel()
        viewModel.deleteAll()
        #expect(viewModel.showError)
        #expect(viewModel.errorMessage != nil)
    }

    /// Without a paired watch the simulator has nothing to update; the request still marks the list
    /// as updating, and an update notification re-reads the watch state, which reads "not paired".
    @Test func manualUpdatesAndTheWatchState() async throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }
        let database = try SettingsTestDatabase.make()
        Current.database = { database }

        let viewModel = ComplicationListViewModel()
        viewModel.updateComplications()
        #expect(viewModel.isUpdatingComplications)
        for _ in 0 ..< 250 where viewModel.isUpdatingComplications {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        NotificationCenter.default.post(
            name: NotificationCommandManager.didUpdateComplicationsNotification,
            object: nil
        )
        #expect(!viewModel.remainingUpdatesDescription.isEmpty)
    }
}
