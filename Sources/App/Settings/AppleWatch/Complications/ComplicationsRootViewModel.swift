import Combine
import Foundation
import Shared

@MainActor
final class ComplicationsRootViewModel: ObservableObject {
    @Published private(set) var configs: [WatchComplicationConfig] = []
    @Published private(set) var subtitles: [String: String] = [:]
    @Published private(set) var hasLegacy = false
    @Published var editing: WatchComplicationConfig?
    @Published var isReloading = false
    @Published var reloadAlert: ReloadAlert?

    /// One-off alert describing the result of the manual "Reload" so it isn't a silent no-op.
    struct ReloadAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// Manual reload: pushes the current complications to the watch and reports the result so the user
    /// isn't left guessing when the watch is away.
    func reload() async {
        isReloading = true
        let outcome = await HomeAssistantAPI.reloadWatchComplications()
        isReloading = false
        switch outcome {
        case .success:
            reloadAlert = ReloadAlert(
                title: L10n.Watch.Complications.Root.reloadSuccessTitle,
                message: L10n.Watch.Complications.Root.reloadSuccessMessage
            )
        case .watchUnavailable:
            reloadAlert = ReloadAlert(
                title: L10n.Watch.Complications.Root.reloadUnavailableTitle,
                message: L10n.Watch.Complications.Root.reloadUnavailableMessage
            )
        case let .failed(message):
            reloadAlert = ReloadAlert(
                title: L10n.Watch.Complications.Root.reloadFailedTitle,
                message: message
            )
        }
    }

    func load() {
        hasLegacy = !((try? WatchComplication.all()) ?? []).isEmpty
        let all = (try? WatchComplicationConfig.all()) ?? []
        configs = all
        var map: [String: String] = [:]
        for config in all {
            switch config.kind {
            case .entity:
                guard let entityId = config.entityId else { continue }
                let key = "\(config.serverId)-\(entityId)"
                let entity = try? Current.database().read { db in
                    try HAAppEntity.fetchOne(db, key: key)
                }
                map[config.id] = entity?.contextualSubtitle ?? config.entityDisplayName ?? entityId
            case .customTemplate:
                map[config.id] = L10n.Watch.Complications.Root.template
            }
        }
        subtitles = map
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            try? configs[index].delete()
        }
        notifyComplicationsChanged()
        load()
    }

    func duplicate(_ config: WatchComplicationConfig) {
        var copy = config
        copy.id = UUID().uuidString
        copy.sortOrder = ((configs.map(\.sortOrder).max()) ?? -1) + 1
        do {
            try copy.save()
            notifyComplicationsChanged()
            load()
            editing = copy
        } catch {
            Current.Log.error("Failed to duplicate complication config: \(error.localizedDescription)")
        }
    }

    private func notifyComplicationsChanged() {
        NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
        HomeAssistantAPI.syncWatchContext()
        WatchMirrorPushCoordinator.schedule(reason: .complicationChanged)
    }
}
