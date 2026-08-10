import Foundation
import GRDB

/// Reports commits touching any GRDB table, so the iCloud sync manager can schedule an
/// upload after local changes without the App target importing GRDB directly.
public final class CloudSyncDatabaseObserver {
    private var cancellable: AnyDatabaseCancellable?

    public init() {}

    public func start(onChange: @escaping () -> Void) {
        guard cancellable == nil else { return }
        let observation = DatabaseRegionObservation(tracking: .fullDatabase)
        cancellable = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("CloudSync database observation failed: \(error)")
            },
            onChange: { _ in
                onChange()
            }
        )
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
