import Combine
import Foundation
import GRDB
import Shared

@MainActor
final class SiriServerConfigurationViewModel: ObservableObject {
    struct Item: Identifiable, Equatable {
        let id: String
        let entityId: String
        let name: String
        var isExposed: Bool
    }

    @Published var calendars: [Item] = []
    @Published var lists: [Item] = []
    @Published var defaultCalendarId: String?
    @Published var defaultListId: String?
    @Published var isReloading = false

    let server: Server
    private let refresh: (Server) -> Void
    private var reloadTimeout: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        server: Server,
        refresh: @escaping (Server) -> Void = { $0.refreshAppDatabase(forceUpdate: true, showProgress: false) }
    ) {
        self.server = server
        self.refresh = refresh
        NotificationCenter.default.publisher(for: .appDatabaseUpdaterDidFinishRoutine)
            .filter { ($0.object as? Server)?.identifier == server.identifier }
            .sink { [weak self] _ in
                Task { @MainActor in self?.finishReloading() }
            }
            .store(in: &cancellables)
    }

    var serverName: String { server.info.name }

    func load() {
        let serverId = server.identifier.rawValue
        let hidden = SiriEntityExposure.hiddenEntityIds()
        calendars = HACalendar.all(serverId: serverId).map { calendar in
            Item(
                id: calendar.id,
                entityId: calendar.entityId,
                name: calendar.name,
                isExposed: !hidden.contains(calendar.id)
            )
        }
        lists = todoEntities(serverId: serverId).map { entity in
            Item(id: entity.id, entityId: entity.entityId, name: entity.name, isExposed: !hidden.contains(entity.id))
        }
        defaultCalendarId = SiriEntityExposure.defaultEntityId(serverId: serverId, domain: Domain.calendar.rawValue)
        defaultListId = SiriEntityExposure.defaultEntityId(serverId: serverId, domain: Domain.todo.rawValue)
    }

    func setExposed(_ isExposed: Bool, item: Item, domain: Domain) {
        SiriEntityExposure.setExposed(
            isExposed,
            serverId: server.identifier.rawValue,
            entityId: item.entityId,
            domain: domain.rawValue
        )
        load()
        NotificationCenter.default.post(name: .siriEntityExposureDidChange, object: nil)
    }

    func setDefault(_ id: String?, domain: Domain) {
        let entityId = items(for: domain).first { $0.id == id }?.entityId
        SiriEntityExposure.setDefault(entityId: entityId, serverId: server.identifier.rawValue, domain: domain.rawValue)
        load()
        NotificationCenter.default.post(name: .siriEntityExposureDidChange, object: nil)
    }

    func reload() {
        guard !isReloading else { return }
        isReloading = true
        reloadTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.finishReloading()
        }
        refresh(server)
    }

    private func finishReloading() {
        reloadTimeout?.cancel()
        reloadTimeout = nil
        load()
        isReloading = false
    }

    private func items(for domain: Domain) -> [Item] {
        domain == .calendar ? calendars : lists
    }

    private func todoEntities(serverId: String) -> [HAAppEntity] {
        do {
            return try Current.database().read { db in
                try HAAppEntity
                    .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.todo.rawValue)
                    .order(Column(DatabaseTables.AppEntity.name.rawValue))
                    .fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to load to-do lists for \(serverId), error: \(error.localizedDescription)")
            return []
        }
    }
}
