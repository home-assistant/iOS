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
    @Published var sensorPrivacy: ServerSensorPrivacy = .none
    @Published var showDeleteConfirmation = false
    @Published var isDeleting = false
    @Published var clientCertificate: ClientCertificate?
    @Published var isImportingCertificate = false
    @Published var certificateError: Error?

    // MARK: - Properties

    let server: Server
    private var tokens: [HACancellable] = []
    private var localPushObserver: HACancellable?
    private var notificationCenterObserver: NSObjectProtocol?

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
        localPushObserver?.cancel()
        if let observer = notificationCenterObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func updateAppDatabase() {
        server.refreshAppDatabase(forceUpdate: true)
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
            notificationCenterObserver = NotificationCenter.default.addObserver(
                forName: HAConnectionState.didTransitionToStateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.websocketState = Current.api(for: self.server)?.connection.state
                }
            }
            websocketState = connection.state

            // Observe logged in user
            tokens.append(connection.caches.user.subscribe { [weak self] _, user in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.loggedInUser = user.name ?? ""
                }
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
        clientCertificate = server.info.connection.clientCertificate
    }

    private func updateFromServerInfo(_ info: ServerInfo) {
        serverName = info.name
        connectionPath = info.connection.activeURLType.description
        version = info.version.description
        locationName = info.setting(for: .localName) ?? ""
        deviceName = info.setting(for: .overrideDeviceName) ?? ""
        securityLevel = info.connection.connectionAccessSecurityLevel
        locationPrivacy = info.setting(for: .locationPrivacy)
        sensorPrivacy = info.setting(for: .sensorPrivacy)
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
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
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

        await race(
            when(resolved: Current.apis.map { $0.tokenManager.revokeToken() }).asVoid(),
            after(seconds: 10.0)
        ).async()

        await waitAtLeast.async()

        Current.api(for: server)?.connection.disconnect()
        Current.servers.remove(identifier: server.identifier)
        Current.onboardingObservation.needed(.logout)
    }

    // MARK: - Client Certificate

    /// Import a PKCS#12 certificate file
    func importCertificate(from url: URL, password: String) async {
        isImportingCertificate = true
        certificateError = nil

        do {
            // Read the file data
            let data = try Data(contentsOf: url)

            // Generate unique identifier for this server's certificate
            let identifier = server.identifier.rawValue

            // Import into Keychain
            let certificate = try ClientCertificateManager.shared.importP12(
                data: data,
                password: password,
                identifier: identifier
            )

            // Update server connection info
            server.update { info in
                info.connection.clientCertificate = certificate
            }

            clientCertificate = certificate
            Current.Log.info("Successfully imported client certificate: \(certificate.displayName)")
        } catch {
            Current.Log.error("Failed to import certificate: \(error)")
            certificateError = error
        }

        isImportingCertificate = false
    }

    /// Remove the current client certificate
    func removeCertificate() {
        guard let certificate = clientCertificate else { return }

        do {
            try ClientCertificateManager.shared.delete(certificate: certificate)
        } catch {
            Current.Log.error("Failed to delete certificate from Keychain: \(error)")
        }

        server.update { info in
            info.connection.clientCertificate = nil
        }

        clientCertificate = nil
        Current.Log.info("Removed client certificate")
    }
}
