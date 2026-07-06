import Foundation
import GRDB
import Shared

/// Observable wrapper around a GRDB `ValueObservation` for use in SwiftUI.
///
/// Publishes a plain Swift array so SwiftUI views can observe it via
/// `@StateObject` / `@ObservedObject`. GRDB delivers the initial value and any
/// subsequent changes on the main queue. Replaces the Realm-based
/// `RealmResultsObserver`.
@MainActor
final class DatabaseResultsObserver<RecordType: FetchableRecord>: ObservableObject {
    @Published private(set) var items: [RecordType] = []

    private var token: AnyDatabaseCancellable?

    init(request: @escaping (Database) throws -> [RecordType]) {
        let observation = ValueObservation.tracking { db in
            try request(db)
        }

        self.token = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("couldn't observe database results: \(error)")
            },
            onChange: { [weak self] items in
                Task { @MainActor [weak self] in
                    self?.items = items
                }
            }
        )
    }

    deinit {
        token?.cancel()
    }
}
