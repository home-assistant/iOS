@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

@Suite(.serialized)
struct SiriServerConfigurationViewTests {
    @MainActor
    @Test func siriServerConfigurationWithCalendarsAndLists() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        server.update { $0.remoteName = "Home" }
        Current.servers = manager
        let serverId = server.identifier.rawValue
        try await SiriTestSeeding.clear(serverIds: [serverId])
        try await SiriTestSeeding.seedCalendar(
            serverId: serverId,
            entityId: "calendar.family",
            name: "Family",
            sortOrder: 0
        )
        try await SiriTestSeeding.seedCalendar(
            serverId: serverId,
            entityId: "calendar.work",
            name: "Work",
            sortOrder: 1
        )
        try await SiriTestSeeding.seedTodoList(serverId: serverId, entityId: "todo.shopping", name: "Shopping")
        try await SiriTestSeeding.seedTodoList(serverId: serverId, entityId: "todo.chores", name: "Chores")
        try await SiriTestSeeding.seedTodoList(serverId: serverId, entityId: "todo.projects", name: "Projects")
        SiriEntityExposure.setDefault(entityId: "calendar.family", serverId: serverId, domain: Domain.calendar.rawValue)
        SiriEntityExposure.setDefault(entityId: "todo.shopping", serverId: serverId, domain: Domain.todo.rawValue)
        SiriEntityExposure.setExposed(
            false,
            serverId: serverId,
            entityId: "todo.projects",
            domain: Domain.todo.rawValue
        )

        let viewModel = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
        assertLightDarkSnapshots(of: SiriServerConfigurationView(viewModel: viewModel), drawHierarchyInKeyWindow: true)

        try await SiriTestSeeding.clear(serverIds: [serverId])
    }

    @MainActor
    @Test func siriServerConfigurationWithNothingStored() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager
        try await SiriTestSeeding.clear(serverIds: [server.identifier.rawValue])

        let viewModel = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
        assertLightDarkSnapshots(of: SiriServerConfigurationView(viewModel: viewModel), drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func siriServerConfigurationShowsProgressWhileReloading() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager
        try await SiriTestSeeding.clear(serverIds: [server.identifier.rawValue])

        let viewModel = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
        viewModel.reload()
        let window = UIWindow(frame: .init(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: NavigationView { SiriServerConfigurationView(viewModel: viewModel) }
        )
        window.isHidden = false
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        #expect(viewModel.isReloading)
        #expect(Self.containsView(ofType: UIActivityIndicatorView.self, in: window))
        window.isHidden = true
    }

    private static func containsView(ofType type: UIView.Type, in view: UIView) -> Bool {
        if view.isKind(of: type) {
            return true
        }
        return view.subviews.contains { containsView(ofType: type, in: $0) }
    }
}
