import Foundation
import RealmSwift

/// Observable wrapper around an `AnyRealmCollection` for use in SwiftUI.
///
/// Mirrors Realm results changes onto the main thread and publishes a plain
/// Swift array so SwiftUI views can observe it via `@StateObject` /
/// `@ObservedObject`. Replaces the Eureka `RealmSection` wrapper for views
/// that previously relied on Realm notifications.
final class RealmResultsObserver<ObjectType: Object>: ObservableObject {
    @Published private(set) var items: [ObjectType] = []

    private let collection: AnyRealmCollection<ObjectType>
    private var token: NotificationToken?

    init(collection: AnyRealmCollection<ObjectType>) {
        self.collection = collection
        self.items = Array(collection)

        self.token = collection.observe { [weak self] change in
            guard let self else { return }
            switch change {
            case let .initial(collection):
                self.items = Array(collection)
            case let .update(collection, _, _, _):
                self.items = Array(collection)
            case .error:
                break
            }
        }
    }

    deinit {
        token?.invalidate()
    }
}
