import Foundation
import PromiseKit
import RealmSwift
import Shared

/// Value-type snapshot of a scene for safe SwiftUI rendering.
struct ActionsSceneSnapshot: Identifiable, Equatable {
    var id: String { identifier }
    let identifier: String
    let name: String?
    let icon: String?
    let actionEnabled: Bool
}

/// Value-type snapshot of an `Action` row for safe SwiftUI rendering.
struct ActionRowSnapshot: Identifiable, Equatable {
    var id: String { actionID }
    let actionID: String
    let name: String
    let text: String
    let iconName: String
}

/// View model for `ActionsSettingsView`.
///
/// Wraps Realm observation for `Action` and `RLMScene` results and exposes them
/// as `@Published` snapshot arrays so the SwiftUI view does not touch Realm
/// directly from its body.
final class ActionsSettingsViewModel: ObservableObject {
    @Published private(set) var localActions: [ActionRowSnapshot] = []
    @Published private(set) var serverActions: [ActionRowSnapshot] = []
    @Published private(set) var scenes: [ActionsSceneSnapshot] = []
    @Published private(set) var isRefreshing: Bool = false

    private let realm: Realm
    private var actionsToken: NotificationToken?
    private var scenesToken: NotificationToken?

    init() {
        self.realm = Current.realm()
        setupObservers()
    }

    deinit {
        actionsToken?.invalidate()
        scenesToken?.invalidate()
    }

    // MARK: - Observation

    private func setupObservers() {
        let actions = realm.objects(Action.self)
            .sorted(byKeyPath: "Position")
            .filter("Scene == nil")

        actionsToken = actions.observe { [weak self] _ in
            self?.refresh(actions: actions)
        }
        refresh(actions: actions)

        let scenes = realm.objects(RLMScene.self)
            .sorted(byKeyPath: RLMScene.positionKeyPath)
        scenesToken = scenes.observe { [weak self] _ in
            self?.refresh(scenes: scenes)
        }
        refresh(scenes: scenes)
    }

    private func refresh(actions: Results<Action>) {
        localActions = actions.filter("isServerControlled == false").map(Self.snapshot(from:))
        serverActions = actions.filter("isServerControlled == true").map(Self.snapshot(from:))
    }

    private static func snapshot(from action: Action) -> ActionRowSnapshot {
        ActionRowSnapshot(
            actionID: action.ID,
            name: action.Name,
            text: action.Text,
            iconName: action.IconName
        )
    }

    /// Loads an unmanaged copy of the managed `Action` with the given identifier, or
    /// `nil` if it no longer exists (deleted concurrently).
    func loadAction(id: String) -> Action? {
        guard let stored = realm.object(ofType: Action.self, forPrimaryKey: id) else { return nil }
        return Action(value: stored)
    }

    private func refresh(scenes: Results<RLMScene>) {
        self.scenes = scenes.map {
            ActionsSceneSnapshot(
                identifier: $0.identifier,
                name: $0.name,
                icon: $0.icon,
                actionEnabled: $0.actionEnabled
            )
        }
    }

    // MARK: - Mutations

    func save(action: Action) {
        // For brand-new local actions (no managed copy yet) assign a position at the end of
        // the current local list. Without this, the default `Position = 0` makes the new
        // action sort to the top of the manual section once Realm publishes the change.
        let isNewLocal = action.Scene == nil
            && !action.isServerControlled
            && realm.object(ofType: Action.self, forPrimaryKey: action.ID) == nil
        if isNewLocal {
            action.Position = Action.PositionOffset.manual.rawValue + localActions.count
        }
        realm.reentrantWrite { [realm] in
            realm.add(action, update: .all)
        }.done { [weak self] in
            self?.updatePositions()
        }.cauterize()
    }

    func deleteLocalActions(at offsets: IndexSet) {
        let ids = offsets.compactMap { index -> String? in
            guard index < localActions.count else { return nil }
            return localActions[index].actionID
        }
        guard !ids.isEmpty else { return }
        realm.reentrantWrite { [realm] in
            realm.delete(realm.objects(Action.self).filter("ID IN %@", ids))
        }.cauterize()
    }

    func moveLocalActions(from source: IndexSet, to destination: Int) {
        var reordered = localActions
        reordered.move(fromOffsets: source, toOffset: destination)
        localActions = reordered

        let ids = reordered.map(\.actionID)
        realm.reentrantWrite { [realm] in
            let stored = realm.objects(Action.self).filter("ID IN %@", ids)
            for action in stored {
                guard let newIndex = ids.firstIndex(of: action.ID) else { continue }
                action.Position = Action.PositionOffset.manual.rawValue + newIndex
            }
        }.cauterize()
    }

    func setSceneEnabled(_ sceneId: String, enabled: Bool) {
        realm.reentrantWrite { [realm] in
            guard let scene = realm.object(ofType: RLMScene.self, forPrimaryKey: sceneId) else { return }
            scene.actionEnabled = enabled
        }.cauterize()
    }

    func firstAction(forSceneId sceneId: String) -> Action? {
        guard let scene = realm.object(ofType: RLMScene.self, forPrimaryKey: sceneId) else {
            return nil
        }
        return scene.actions.first.map { Action(value: $0) }
    }

    func refreshServerActions() {
        isRefreshing = true
        let result = Current.modelManager.fetch()
        result.pipe { [weak self] result in
            DispatchQueue.main.async {
                self?.isRefreshing = false
            }
            switch result {
            case .fulfilled:
                break
            case let .rejected(error):
                Current.Log.error("Failed to manually update server Actions: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func updatePositions() {
        let ids = localActions.map(\.actionID)
        realm.reentrantWrite { [realm] in
            let stored = realm.objects(Action.self).filter("ID IN %@", ids)
            for action in stored {
                guard let newIndex = ids.firstIndex(of: action.ID) else { continue }
                action.Position = Action.PositionOffset.manual.rawValue + newIndex
            }
        }.cauterize()
    }
}
