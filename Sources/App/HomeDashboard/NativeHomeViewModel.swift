import Combine
import Foundation
import HAKit
import PromiseKit
import Shared
import SwiftUI

/// Keeps the native home in step with a server: loads the registries once, follows the states as
/// they change, regenerates the dashboard from them, and carries out what the user taps.
@MainActor
final class NativeHomeViewModel: ObservableObject {
    @Published private(set) var dashboard: HomeDashboardConfig?
    @Published private(set) var registry = HomeRegistry()
    @Published private(set) var isLoading = true
    @Published private(set) var presenter: HomeEntityPresenter = .preview

    private let server: Server
    private var statesToken: HACancellable?
    private var entities: [String: HAEntity] = [:]
    private var iconsMap: EntityComponentIconsMap?
    private var strategyConfig = HomeDashboardStrategyConfig()
    /// True once the registries are in: state updates before that would generate against nothing.
    private var hasLoadedRegistries = false

    init(server: Server) {
        self.server = server
    }

    deinit {
        statesToken?.cancel()
    }

    // MARK: - Loading

    func start() async {
        subscribeToStates()
        iconsMap = await Current.entityComponentIcons().fetch(for: server)
        strategyConfig = await loadStrategyConfig()
        await reloadRegistries()
    }

    /// Re-reads the registries. The states keep flowing on their own — this is for what does not
    /// change often enough to subscribe to: areas, floors, devices, panels.
    func reloadRegistries() async {
        let user = await currentUser()
        registry = await NativeHomeRegistryLoader.load(
            server: server,
            states: entities,
            isAdmin: user?.isAdmin ?? false,
            userName: user?.name,
            hasEnergyData: registry.hasEnergyData
        )
        hasLoadedRegistries = true
        regenerate()
    }

    private func subscribeToStates() {
        statesToken?.cancel()
        statesToken = Current.api(for: server)?.connection.caches.states().subscribe { [weak self] _, states in
            Task { @MainActor [weak self] in
                self?.apply(states: states)
            }
        }
    }

    private func apply(states: HACachedStates) {
        entities = Dictionary(states.all.map { ($0.entityId, $0) }, uniquingKeysWith: { first, _ in first })
        presenter = .app(entities: entities, iconsMap: iconsMap, serverId: server.identifier.rawValue)
        guard hasLoadedRegistries else {
            return
        }
        registry = registry.updating(states: entities.values.map(NativeHomeRegistryLoader.homeState))
        regenerate()
    }

    private func regenerate() {
        dashboard = HomeDashboardStrategy.generate(
            config: strategyConfig,
            registry: registry,
            strings: .app
        )
        isLoading = false
    }

    /// The options the dashboard is generated with. Only the suggestions are asked for over the
    /// wire; what the user pinned lives in their frontend settings, which the app does not read yet.
    private func loadStrategyConfig() async -> HomeDashboardStrategyConfig {
        await HomeDashboardStrategyConfig(
            suggestedEntityIds: suggestedEntityIds(),
            isHomePanel: true
        )
    }

    private func suggestedEntityIds() async -> [String] {
        guard let connection = Current.api(for: server)?.connection else {
            return []
        }
        return await withCheckedContinuation { continuation in
            connection.send(HATypedRequest<HAUsagePredictionCommonControl>.usagePredictionCommonControl()) { result in
                switch result {
                case let .success(prediction):
                    continuation.resume(returning: prediction.entities)
                case .failure:
                    // The integration is optional; without it the row simply holds what was pinned.
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func currentUser() async -> HAResponseCurrentUser? {
        guard let connection = Current.api(for: server)?.connection else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            connection.send(HATypedRequest<HAResponseCurrentUser>.fetchCurrentUser()) { result in
                continuation.resume(returning: try? result.get())
            }
        }
    }

    // MARK: - Acting on a tap

    func perform(_ action: HomeDashboardAction) {
        switch action {
        case let .navigate(path):
            navigate(to: path)
        case let .performAction(call):
            perform(call)
        case let .moreInfo(entityId):
            // The frontend's more-info dialog is the web view's; deep-linking to it is how the rest
            // of the app opens one.
            navigate(to: "?more-info-entity-id=\(entityId)")
        }
    }

    private func navigate(to path: String) {
        guard let baseURL = server.activeURLUsingLastKnownNetworkState(),
              let url = URL(string: path, relativeTo: baseURL) else {
            Current.Log.error("Native home could not resolve \(path) against the server's URL")
            return
        }
        Current.sceneManager.webViewControllerPromise.done { controller in
            controller.open(inline: url)
        }
    }

    private func perform(_ call: HomeServiceCall) {
        guard let connection = Current.api(for: server)?.connection else {
            return
        }
        let parts = call.service.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            Current.Log.error("Native home was asked for a malformed action: \(call.service)")
            return
        }
        var target: [String: Any] = [:]
        if let areaId = call.areaId {
            target["area_id"] = areaId
        }
        if let entityId = call.entityId {
            target["entity_id"] = entityId
        }
        connection.send(HATypedRequest<CallServiceResponse>.callService(
            domain: parts[0],
            service: parts[1],
            serviceData: target,
            returnResponse: false
        )) { result in
            if case let .failure(error) = result {
                Current.Log.error("Native home action \(call.service) failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Reordering

    /// Hands a new order of rooms to the server, which is where the web frontend reads it from too —
    /// so dragging a room here moves it in the browser as well.
    func reorderAreas(_ areaIds: [String]) {
        guard let connection = Current.api(for: server)?.connection else {
            return
        }
        connection.send(HATypedRequest<HAResponseVoid>.reorderAreaRegistry(areaIds: areaIds)) { [weak self] result in
            switch result {
            case .success:
                Task { @MainActor [weak self] in
                    await self?.reloadRegistries()
                }
            case let .failure(error):
                Current.Log.error("Native home failed to reorder the areas: \(error.localizedDescription)")
            }
        }
    }
}
