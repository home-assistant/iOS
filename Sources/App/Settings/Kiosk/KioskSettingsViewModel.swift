import Combine
import Foundation
import Shared

@MainActor
final class KioskSettingsViewModel: ObservableObject {
    @Published var settings = KioskSettings()
    @Published var servers: [Server] = []
    @Published var panels: [AppPanel] = []
    @Published var showError = false
    @Published private(set) var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true

    init() {
        load()
        setupAutoSave()
    }

    private func setupAutoSave() {
        $settings
            .dropFirst() // Skip the value emitted for the current state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !self.isInitialLoad else { return }
                save()
            }
            .store(in: &cancellables)
    }

    func load() {
        servers = Current.servers.all
        do {
            if let stored = try KioskSettings.current() {
                settings = stored
            } else {
                settings = KioskSettings()
            }
        } catch {
            Current.Log.error("Failed to load kiosk settings: \(error.localizedDescription)")
        }
        if settings.serverId == nil {
            settings.serverId = servers.first?.identifier.rawValue
        }
        reloadPanels()
        isInitialLoad = false
    }

    func reloadPanels() {
        guard let serverId = settings.serverId else {
            panels = []
            return
        }
        do {
            panels = try AppPanel.panels(serverId: serverId) ?? []
        } catch {
            Current.Log.error("Failed to load kiosk dashboards: \(error.localizedDescription)")
            panels = []
        }
    }

    func serverDidChange() {
        settings.dashboard = nil
        reloadPanels()
    }

    @discardableResult
    func save() -> Bool {
        do {
            try Current.database().write { db in
                try settings.insert(db, onConflict: .replace)
            }
            return true
        } catch {
            Current.Log.error("Failed to save kiosk settings: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}
