import Combine
import Foundation
import HAKit
import PromiseKit
import Shared
import UIKit

/// ViewModel for ConnectionSettingsView, managing server connection settings and state
@MainActor
final class ConnectionSettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var serverName: String = ""
    @Published var connectionPath: String = ""
    @Published var version: String = ""
    @Published var websocketState: HAConnectionState?
    @Published var localPushStatus: String = ""
    @Published var loggedInUser: String = ""
    @Published var locationName: String = ""
    @Published var deviceName: String = ""
    @Published var internalURL: String = ""
    @Published var externalURL: String = ""
    @Published var securityLevel: ConnectionSecurityLevel = .mostSecure
    @Published var locationPrivacy: ServerLocationPrivacy = .never
    @Published var sensorPrivacy: ServerSensorPrivacy = .never
    @Published var showDeleteConfirmation = false
    @Published var isDeleting = false
    
    // MARK: - Properties
    
    let server: Server
    private var tokens: [HACancellable] = []
    private var localPushObserver: Any?
    
    // MARK: - Computed Properties
    
    var canShareServer: Bool {
        server.info.connection.invitationURL() != nil
    }
    
    var hasMultipleServers: Bool {
        Current.servers.all.count > 1
    }
    
    var versionRequiresLocationGPSOptional: Bool {
        server.info.version <= .updateLocationGPSOptional
    }
    
    // MARK: - Initialization
    
    init(server: Server) {
        self.server = server
        setupObservers()
        loadInitialData()
    }
    
    deinit {
        tokens.forEach { $0.cancel() }
        if let observer = localPushObserver {
            Current.notificationManager.localPushManager.removeObserver(observer)
        }
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe server info changes
        tokens.append(server.observe { [weak self] info in
            self?.updateFromServerInfo(info)
        })
        
        // Observe websocket connection
        if let connection = Current.api(for: server)?.connection {
            // Observe websocket state
            NotificationCenter.default.addObserver(
                forName: HAConnectionState.didTransitionToStateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.websocketState = connection.state
            }
            websocketState = connection.state
            
            // Observe logged in user
            tokens.append(connection.caches.user.subscribe { [weak self] _, user in
                self?.loggedInUser = user.name
            })
        }
        
        // Observe local push notifications
        let manager = Current.notificationManager.localPushManager
        localPushObserver = manager.addObserver(for: server) { [weak self] _ in
            self?.updateLocalPushStatus()
        }
        updateLocalPushStatus()
    }
    
    private func loadInitialData() {
        updateFromServerInfo(server.info)
        updateURLs()
    }
    
    private func updateFromServerInfo(_ info: ServerInfo) {
        serverName = info.name
        connectionPath = info.connection.activeURLType.description
        version = info.version.description
        locationName = info.setting(for: .localName) ?? ""
        deviceName = info.setting(for: .overrideDeviceName) ?? ""
        securityLevel = info.connection.connectionAccessSecurityLevel
        locationPrivacy = info.setting(for: .locationPrivacy) ?? .never
        sensorPrivacy = info.setting(for: .sensorPrivacy) ?? .never
        updateURLs()
    }
    
    private func updateURLs() {
        internalURL = server.info.connection.address(for: .internal)?.absoluteString ?? "—"
        
        if server.info.connection.useCloud, server.info.connection.canUseCloud {
            externalURL = L10n.Settings.ConnectionSection.HomeAssistantCloud.title
        } else {
            externalURL = server.info.connection.address(for: .external)?.absoluteString ?? "—"
        }
    }
    
    private func updateLocalPushStatus() {
        let manager = Current.notificationManager.localPushManager
        switch manager.status(for: server) {
        case .disabled:
            localPushStatus = L10n.SettingsDetails.Notifications.LocalPush.Status.disabled
        case .unsupported:
            localPushStatus = L10n.SettingsDetails.Notifications.LocalPush.Status.unsupported
        case let .allowed(state):
            switch state {
            case .unavailable:
                localPushStatus = L10n.SettingsDetails.Notifications.LocalPush.Status.unavailable
            case .establishing:
                localPushStatus = L10n.SettingsDetails.Notifications.LocalPush.Status.establishing
            case let .available(received: received):
                let formatted = NumberFormatter.localizedString(
                    from: NSNumber(value: received),
                    number: .decimal
                )
                localPushStatus = L10n.SettingsDetails.Notifications.LocalPush.Status.available(formatted)
            }
        }
    }
    
    // MARK: - Actions
    
    func updateLocationName(_ newName: String?) {
        server.info.setSetting(value: newName, for: .localName)
        locationName = newName ?? ""
    }
    
    func updateDeviceName(_ newName: String?) {
        server.info.setSetting(value: newName, for: .overrideDeviceName)
        deviceName = newName ?? ""
    }
    
    func updateSecurityLevel(_ level: ConnectionSecurityLevel) {
        server.update { info in
            info.connection.connectionAccessSecurityLevel = level
        }
        securityLevel = level
    }
    
    func updateLocationPrivacy(_ privacy: ServerLocationPrivacy) {
        server.info.setSetting(value: privacy, for: .locationPrivacy)
        locationPrivacy = privacy
        HomeAssistantAPI.manuallyUpdate(
            applicationState: UIApplication.shared.applicationState,
            type: .programmatic
        ).cauterize()
    }
    
    func updateSensorPrivacy(_ privacy: ServerSensorPrivacy) {
        server.info.setSetting(value: privacy, for: .sensorPrivacy)
        sensorPrivacy = privacy
        Current.api(for: server)?.registerSensors().cauterize()
    }
    
    func shareServer() -> UIActivityViewController? {
        guard let invitationServerURL = server.info.connection.invitationURL() else {
            Current.Log.error("Invitation button failed, no invitation URL found for server \(server.identifier)")
            return nil
        }
        
        guard let invitationURL = AppConstants.invitationURL(serverURL: invitationServerURL) else {
            Current.Log
                .error("Invitation button failed, could not create invitation URL for server \(server.identifier)")
            return nil
        }
        
        return UIActivityViewController(activityItems: [invitationURL], applicationActivities: nil)
    }
    
    func activateServer() {
        if Current.isCatalyst, Current.settingsStore.macNativeFeaturesOnly {
            if let url = server.info.connection.activeURL() {
                UIApplication.shared.open(url)
            }
        } else {
            Current.sceneManager.webViewWindowControllerPromise.done {
                $0.open(server: self.server)
            }
        }
    }
    
    func deleteServer() async throws {
        isDeleting = true
        defer { isDeleting = false }
        
        let waitAtLeast = after(seconds: 3.0)
        
        do {
            _ = try await race(
                when(resolved: Current.apis.map { $0.tokenManager.revokeToken() }).asVoid(),
                after(seconds: 10.0)
            ).async()
            
            try await waitAtLeast.async()
            
            Current.api(for: server)?.connection.disconnect()
            Current.servers.remove(identifier: server.identifier)
            Current.onboardingObservation.needed(.logout)
        } catch {
            throw error
        }
    }
}
