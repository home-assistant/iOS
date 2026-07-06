import CarPlay
import Foundation
import HAKit
import Shared

final class CarPlayServerListViewModel {
    weak var templateProvider: CarPlayServersListTemplate?
    weak var interfaceController: CPInterfaceController?
    private var pendingTabs: [CarPlayTab]?
    private var pendingLayout: CarPlayQuickAccessLayout?
    private var pendingServer: Server?

    func removeServerObserver() {
        Current.servers.remove(observer: self)
    }

    func addServerObserver() {
        removeServerObserver()
        Current.servers.add(observer: self)
    }

    func setServer(server: Server) {
        CarPlayPreferredServer.select(server)
        templateProvider?.update()
        templateProvider?.sceneDelegate?.setup()
    }

    func beginServerSelection() {
        pendingServer = CarPlayPreferredServer.current
    }

    func isServerActive(_ server: Server) -> Bool {
        (pendingServer ?? CarPlayPreferredServer.current)?.identifier == server.identifier
    }

    func setServer(_ server: Server) {
        pendingServer = server
    }

    func commitServerSelection() {
        guard let pendingServer else {
            return
        }
        self.pendingServer = nil

        guard pendingServer.identifier != CarPlayPreferredServer.current?.identifier else {
            return
        }

        setServer(server: pendingServer)
    }

    var tabs: [CarPlayTab] {
        do {
            return try tabsWithMandatorySettings(CarPlayConfig.config()?.tabs ?? CarPlayConfig().tabs)
        } catch {
            Current.Log.error("Failed to fetch CarPlay tabs: \(error.localizedDescription)")
            return tabsWithMandatorySettings(CarPlayConfig().tabs)
        }
    }

    func beginTabSelection() {
        pendingTabs = tabs
    }

    func isTabActive(_ tab: CarPlayTab) -> Bool {
        (pendingTabs ?? tabs).contains(tab)
    }

    func setTab(_ tab: CarPlayTab, active: Bool) {
        guard tab != .settings else {
            return
        }

        var tabs = tabsWithMandatorySettings(pendingTabs ?? tabs)
        if active {
            guard !tabs.contains(tab) else {
                return
            }
            tabs.append(tab)
        } else {
            tabs.removeAll { $0 == tab }
        }
        pendingTabs = tabsWithMandatorySettings(tabs)
    }

    func commitTabSelection() {
        guard let pendingTabs else {
            return
        }
        self.pendingTabs = nil

        let tabs = tabsWithMandatorySettings(pendingTabs)
        guard tabs != self.tabs else {
            return
        }

        do {
            var config = try CarPlayConfig.config() ?? CarPlayConfig()
            config.tabs = tabs
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            templateProvider?.update()
        } catch {
            Current.Log.error("Failed to update CarPlay tabs: \(error.localizedDescription)")
        }
    }

    var tabsSummary: String {
        tabs.map(\.name).joined(separator: ", ")
    }

    var quickAccessLayout: CarPlayQuickAccessLayout {
        do {
            return try CarPlayConfig.config()?.resolvedQuickAccessLayout ?? CarPlayConfig().resolvedQuickAccessLayout
        } catch {
            Current.Log.error("Failed to fetch CarPlay quick access layout: \(error.localizedDescription)")
            return CarPlayConfig().resolvedQuickAccessLayout
        }
    }

    func beginLayoutSelection() {
        pendingLayout = quickAccessLayout
    }

    func isLayoutActive(_ layout: CarPlayQuickAccessLayout) -> Bool {
        (pendingLayout ?? quickAccessLayout) == layout
    }

    func setLayout(_ layout: CarPlayQuickAccessLayout) {
        pendingLayout = layout
    }

    func commitLayoutSelection() {
        guard let pendingLayout else {
            return
        }
        self.pendingLayout = nil

        guard pendingLayout != quickAccessLayout else {
            return
        }

        do {
            var config = try CarPlayConfig.config() ?? CarPlayConfig()
            config.quickAccessLayout = pendingLayout
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            templateProvider?.update()
        } catch {
            Current.Log.error("Failed to update CarPlay quick access layout: \(error.localizedDescription)")
        }
    }

    private func tabsWithMandatorySettings(_ tabs: [CarPlayTab]) -> [CarPlayTab] {
        tabs.filter { $0 != .settings } + [.settings]
    }

    var ttsPlaybackStrategy: CarPlayAssistTTSPlaybackStrategy {
        Current.settingsStore.carPlayAssistDebugSettings.ttsPlaybackStrategy
    }

    func setTTSPlaybackStrategy(_ strategy: CarPlayAssistTTSPlaybackStrategy) {
        var settings = Current.settingsStore.carPlayAssistDebugSettings
        settings.ttsPlaybackStrategy = strategy
        Current.settingsStore.carPlayAssistDebugSettings = settings
        templateProvider?.update()
    }
}

extension CarPlayServerListViewModel: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        guard let server = serverManager.serverOrFirstIfAvailable(
            for: Identifier<Server>(rawValue: CarPlayPreferredServer.id)
        ) else {
            if interfaceController?.presentedTemplate != nil {
                interfaceController?.dismissTemplate(animated: true, completion: nil)
            } else {
                templateProvider?.showNoServerAlert()
            }
            return
        }
        setServer(server: server)
    }
}
