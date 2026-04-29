import Foundation
import RealmSwift

/// Observable wrapper around an `AnyRealmCollection` for use in SwiftUI.
///
/// Publishes a plain Swift array so SwiftUI views can observe it via
/// `@StateObject` / `@ObservedObject`. Realm calls the change handler back on
/// the same thread the observation was registered on (we always construct
/// these from the main-actor isolated views), and the snapshot is taken
/// synchronously and published on the main actor. Replaces the Eureka
/// `RealmSection` wrapper for views that previously relied on Realm
/// notifications.
@MainActor
final class RealmResultsObserver<ObjectType: Object>: ObservableObject {
    @Published private(set) var items: [ObjectType] = []

    private let collection: AnyRealmCollection<ObjectType>
    private var token: NotificationToken?

    init(collection: AnyRealmCollection<ObjectType>) {
        self.collection = collection
        self.items = Array(collection)

        self.token = collection.observe { [weak self] change in
            // Snapshot synchronously on Realm's queue (main thread for our use cases),
            // then hop to the main actor to publish so SwiftUI updates land on main.
            let snapshot: [ObjectType]
            switch change {
            case let .initial(collection):
                snapshot = Array(collection)
            case let .update(collection, _, _, _):
                snapshot = Array(collection)
            case .error:
                return
            }
            Task { @MainActor [weak self] in
                self?.items = snapshot
            }
        }
    }

    deinit {
        token?.invalidate()
    }
}
