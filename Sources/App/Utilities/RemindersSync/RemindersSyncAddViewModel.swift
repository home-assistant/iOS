import EventKit
import Foundation
import Shared

@MainActor
final class RemindersSyncAddViewModel: ObservableObject {
    @Published var selectedServerId: String?
    @Published var selectedTodoEntityId: String?
    @Published var selectedReminderListId: String?
    @Published var direction: RemindersSyncDirection = .bothWays
    @Published private(set) var todoEntitiesByServer: [(Server, [HAAppEntity])] = []
    @Published private(set) var reminderLists: [EKCalendar] = []
    @Published private(set) var hasLoaded = false

    private var existingConfigs: [RemindersSyncConfig] = []

    var servers: [Server] {
        todoEntitiesByServer.map(\.0)
    }

    var todoEntities: [HAAppEntity] {
        todoEntitiesByServer
            .first(where: { $0.0.identifier.rawValue == selectedServerId })?.1 ?? []
    }

    /// Whether any server has a todo list to sync with (servers without lists are filtered out
    /// of `todoEntitiesByServer` on load).
    var hasTodoLists: Bool {
        !todoEntitiesByServer.isEmpty
    }

    /// The exact same list pairing already exists.
    var isDuplicate: Bool {
        existingConfigs.contains { config in
            config.serverId == selectedServerId
                && config.todoEntityId == selectedTodoEntityId
                && config.reminderListId == selectedReminderListId
        }
    }

    var canSave: Bool {
        selectedServerId != nil
            && selectedTodoEntityId != nil
            && selectedReminderListId != nil
            && !isDuplicate
    }

    func load() async {
        existingConfigs = RemindersSyncConfig.all()
        todoEntitiesByServer = ControlEntityProvider(domains: [.todo]).getEntities()
            .filter { !$0.1.isEmpty }

        if RemindersSyncManager.shared.authorizationState == .notDetermined {
            _ = await RemindersSyncManager.shared.requestAccess()
        }
        reminderLists = RemindersSyncManager.shared.reminderLists()

        if selectedServerId == nil {
            selectedServerId = servers.first?.identifier.rawValue
        }
        if selectedTodoEntityId == nil {
            selectedTodoEntityId = todoEntities.first?.entityId
        }
        if selectedReminderListId == nil {
            selectedReminderListId = reminderLists.first?.calendarIdentifier
        }
        hasLoaded = true
    }

    /// Triggers a full app database update for every server, so newly created to-do lists show
    /// up. Progress and completion are reported through the updater's toasts.
    func reloadServers() {
        for server in Current.servers.all {
            server.refreshAppDatabase(forceUpdate: true, showProgress: true)
        }
    }

    func selectedServerChanged() {
        // Entities belong to one server; reset the selection when it no longer matches.
        if !todoEntities.contains(where: { $0.entityId == selectedTodoEntityId }) {
            selectedTodoEntityId = todoEntities.first?.entityId
        }
    }

    /// Persists the new pairing and kicks off its first sync. Returns false when the current
    /// selection can't be saved.
    func save() -> Bool {
        guard canSave,
              let serverId = selectedServerId,
              let entity = todoEntities.first(where: { $0.entityId == selectedTodoEntityId }),
              let list = reminderLists.first(where: { $0.calendarIdentifier == selectedReminderListId }) else { return false }

        RemindersSyncConfig(
            id: UUID().uuidString,
            serverId: serverId,
            todoEntityId: entity.entityId,
            todoEntityName: entity.name,
            reminderListId: list.calendarIdentifier,
            reminderListName: list.title,
            direction: direction
        ).save()
        RemindersSyncManager.shared.syncNow()
        RemindersSyncBackgroundRefresher.schedule()
        return true
    }
}
