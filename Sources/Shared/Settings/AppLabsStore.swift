import Combine
import Foundation
import GRDB

/// Live App Labs feature flags, persisted in GRDB and kept current through a `ValueObservation`.
public final class AppLabsStore: ObservableObject {
    @Published public private(set) var enabledFeatureIds: Set<String>

    private var observation: AnyDatabaseCancellable?

    public init() {
        self.enabledFeatureIds = (try? Self.fetchEnabledFeatureIds()) ?? []
        observe()
    }

    public var enabledFeatureIdsPublisher: AnyPublisher<Set<String>, Never> {
        $enabledFeatureIds.eraseToAnyPublisher()
    }

    public func isEnabled(featureId: String) -> Bool {
        enabledFeatureIds.contains(featureId)
    }

    public func setEnabled(_ enabled: Bool, featureId: String) {
        do {
            try Current.database().write { db in
                try AppLabsFeatureState(id: featureId, isEnabled: enabled).insert(db, onConflict: .replace)
            }
            if enabled {
                enabledFeatureIds.insert(featureId)
            } else {
                enabledFeatureIds.remove(featureId)
            }
        } catch {
            Current.Log.error("Failed to persist App Labs feature \(featureId): \(error)")
        }
    }

    private static func fetchEnabledFeatureIds() throws -> Set<String> {
        try Current.database().read { db in
            let states = try AppLabsFeatureState
                .filter(Column(DatabaseTables.AppLabsFeatureState.isEnabled.rawValue) == true)
                .fetchAll(db)
            return Set(states.map(\.id))
        }
    }

    private func observe() {
        let observation = ValueObservation.tracking { db in try AppLabsFeatureState.fetchAll(db) }
        self.observation = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("App Labs feature observation failed: \(error)")
            },
            onChange: { [weak self] states in
                let enabled = Set(states.filter(\.isEnabled).map(\.id))
                guard self?.enabledFeatureIds != enabled else { return }
                self?.enabledFeatureIds = enabled
            }
        )
    }
}
