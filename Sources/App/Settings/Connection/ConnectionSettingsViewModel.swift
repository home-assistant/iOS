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
    @Published var activeURLType: ConnectionInfo.URLType?
    @Published var version: String = ""
    @Published var websocketState: HAConnectionState?
    @Published var localPushStatus: String = ""
    @Published var canRetryLocalPush = false
    @Published var loggedInUser: String = ""
    @Published var profilePicture: UIImage?
    @Published var locationName: String = ""
    @Published var deviceName: String = ""
    @Published var internalURL: String?
    @Published var externalURL: String?
    /// The address behind the external pill: the remote UI URL while cloud is in use, else the external URL.
    @Published var externalAddress: String?
    @Published var isUsingCloud = false
    @Published var locationPrivacy: ServerLocationPrivacy = .never
    @Published var sensorPrivacy: ServerSensorPrivacy = .none
    @Published var showDeleteConfirmation = false
    @Published var isDeleting = false
    @Published var clientCertificate: ClientCertificate?
    @Published var isImportingCertificate = false
    @Published var certificateError: Error?
    @Published var isCertificateImporterPresented = false
    @Published var isCertificatePasswordPromptPresented = false
    @Published var isRemoveCertificateConfirmationPresented = false
    @Published var certificatePassword = ""
    @Published var pendingCertificateURL: URL?
    @Published var isSyncing = false
    @Published var isEditingInternalURL = false
    @Published var isEditingExternalURL = false
    @Published var isShowingHowItWorks = false
    /// The name the alert is editing, with `nameDraft` as its text.
    @Published var nameBeingEdited: ServerDetailsRowView.EditOption?
    @Published var nameDraft = ""

    // MARK: - Properties

    let server: Server
    private var tokens: [HACancellable] = []
    private var localPushObserver: HACancellable?
    private var notificationCenterObserver: NSObjectProtocol?
    private var syncFinishedObserver: NSObjectProtocol?
    private var canRetryLocalPushTask: Task<Void, Never>?

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
        if let observer = syncFinishedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func updateAppDatabase() {
        isSyncing = true
        server.refreshAppDatabase(forceUpdate: true, showProgress: true)
    }

    // MARK: - Editing

    /// Routes an Edit choice to the alert or sheet that changes it.
    func edit(_ option: ServerDetailsRowView.EditOption) {
        switch option {
        case .locationName:
            nameDraft = locationName
            nameBeingEdited = option
        case .deviceName:
            nameDraft = deviceName
            nameBeingEdited = option
        case .internalURL:
            isEditingInternalURL = true
        case .externalURL:
            isEditingExternalURL = true
        }
    }

    /// What the name alert shows while its field is empty: the value the app falls back to.
    func namePlaceholder(for option: ServerDetailsRowView.EditOption) -> String {
        switch option {
        case .locationName:
            return server.info.remoteName
        case .deviceName:
            return Current.device.deviceName()
        case .internalURL, .externalURL:
            return ""
        }
    }

    func saveNameDraft() {
        defer { nameBeingEdited = nil }
        let newName = nameDraft.isEmpty ? nil : nameDraft
        switch nameBeingEdited {
        case .locationName:
            updateLocationName(newName)
        case .deviceName:
            updateDeviceName(newName)
        case .internalURL, .externalURL, nil:
            break
        }
    }

    func cancelNameEdit() {
        nameBeingEdited = nil
    }

    func retryLocalPush() {
        guard canRetryLocalPush else { return }

        Current.notificationManager.localPushManager.retryLocalPush(for: server, reason: .manual)
        updateLocalPushStatus()
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

        syncFinishedObserver = NotificationCenter.default.addObserver(
            forName: .appDatabaseUpdaterDidFinishServer,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let finishedId = notification.userInfo?[AppDatabaseUpdaterUserInfo.serverIdentifierKey] as? String
            guard let finishedId, finishedId == self?.server.identifier.rawValue else { return }
            Task { @MainActor [weak self] in
                self?.isSyncing = false
            }
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
        guard let api = Current.api(for: server) else { return }
        api.cachedProfilePicture { [weak self] image in
            Task { @MainActor [weak self] in
                guard let self, profilePicture == nil else { return }
                profilePicture = image
            }
        }
        api.currentUser { [weak self] user in
            Task { @MainActor [weak self] in
                self?.loggedInUser = user?.name ?? ""
            }
            guard let user else { return }
            api.profilePicture(for: user) { [weak self] image in
                Task { @MainActor [weak self] in
                    self?.profilePicture = image
                }
            }
        }
    }

    private func updateFromServerInfo(_ info: ServerInfo) {
        serverName = info.name
        // The stored copy re-evaluates the active URL on save, but observers get the value as written,
        // so evaluate a copy here to keep the highlighted pill right after an edit.
        var connection = server.info.connection
        _ = connection.evaluateActiveURL()
        activeURLType = connection.activeURLType
        version = info.version.description
        locationName = info.setting(for: .localName) ?? ""
        deviceName = info.setting(for: .overrideDeviceName) ?? ""
        locationPrivacy = info.setting(for: .locationPrivacy)
        sensorPrivacy = info.setting(for: .sensorPrivacy)
        updateURLs()
        updateCanRetryLocalPush()
    }

    private func updateURLs() {
        internalURL = server.info.connection.address(for: .internal)?.absoluteString
        isUsingCloud = server.info.connection.useCloud && server.info.connection.canUseCloud
        let externalAddress = server.info.connection.address(for: .external)?.absoluteString
        self.externalAddress = isUsingCloud
            ? server.info.connection.address(for: .remoteUI)?.absoluteString
            : externalAddress
        externalURL = isUsingCloud ? L10n.Settings.ConnectionSection.HomeAssistantCloud.title : externalAddress
    }

    private func updateLocalPushStatus() {
        let manager = Current.notificationManager.localPushManager
        updateCanRetryLocalPush()

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

    private func updateCanRetryLocalPush() {
        // Cancel any in-flight update so an older SSID fetch resuming late can't overwrite the
        // result of a newer one.
        canRetryLocalPushTask?.cancel()
        canRetryLocalPushTask = Task { [weak self] in
            guard let self else { return }
            let currentSSID = await Current.connectivity.currentWiFiSSID()
            guard !Task.isCancelled else { return }
            canRetryLocalPush = LocalPushRetryDiagnostics.canRetry(
                server: server,
                currentSSID: currentSSID
            )
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

    func invitationURL() -> URL? {
        guard let invitationServerURL = server.info.connection.invitationURL() else {
            Current.Log.error("Invitation button failed, no invitation URL found for server \(server.identifier)")
            return nil
        }

        guard let invitationURL = AppConstants.invitationURL(serverURL: invitationServerURL) else {
            Current.Log
                .error("Invitation button failed, could not create invitation URL for server \(server.identifier)")
            return nil
        }

        return invitationURL
    }

    func activateServer() {
        if Current.isCatalyst, Current.settingsStore.macNativeFeaturesOnly {
            Task { [weak self] in
                guard let self, let url = await server.activeURL() else { return }
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        } else {
            Current.sceneManager.appCoordinator.done {
                $0.activate(server: self.server)
            }
        }
    }

    func deleteServer() async throws {
        isDeleting = true
        defer { isDeleting = false }

        await server.deleteFromApp(minimumDuration: 3.0)
    }

    // MARK: - Client Certificate

    /// Import a PKCS#12 certificate file
    func importCertificate(from url: URL, password: String) async {
        isImportingCertificate = true
        certificateError = nil

        // Perform file I/O and Keychain work off the main actor
        let serverIdentifier = server.identifier.rawValue
        let resultTask = Task.detached(priority: .utility) { () -> Result<ClientCertificate> in
            // Access security-scoped resource for file-importer URLs
            guard url.startAccessingSecurityScopedResource() else {
                return .rejected(ClientCertificateError.invalidP12Data)
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                // Read the file data
                let data = try Data(contentsOf: url)

                // Import into Keychain
                let certificate = try ClientCertificateManager.shared.importP12(
                    data: data,
                    password: password,
                    identifier: serverIdentifier
                )
                return .fulfilled(certificate)
            } catch {
                return .rejected(error)
            }
        }
        let result = await resultTask.value

        switch result {
        case let .fulfilled(certificate):
            let replacedCertificate = server.info.connection.clientCertificate

            // Update server connection info
            server.update { info in
                info.connection.clientCertificate = certificate
            }

            if let replacedCertificate,
               replacedCertificate.keychainIdentifier != certificate.keychainIdentifier {
                deleteCertificateIfUnreferenced(replacedCertificate)
            }

            clientCertificate = certificate
            Current.Log.info("Successfully imported client certificate: \(certificate.displayName)")
        case let .rejected(error):
            Current.Log.error("Failed to import certificate: \(error)")
            certificateError = error
        }

        isImportingCertificate = false
    }

    /// Takes the file picker's result: a chosen file waits for its password, a failure is only logged.
    func handleCertificatePick(_ result: Swift.Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            pendingCertificateURL = url
            isCertificatePasswordPromptPresented = true
        case let .failure(error):
            Current.Log.error("Failed to select certificate file: \(error)")
        }
    }

    func cancelCertificateImport() {
        certificatePassword = ""
        pendingCertificateURL = nil
    }

    /// Imports the picked file with the entered password, then forgets both.
    func confirmCertificateImport() async {
        guard let url = pendingCertificateURL else { return }
        await importCertificate(from: url, password: certificatePassword)
        cancelCertificateImport()
    }

    /// Remove the current client certificate
    func removeCertificate() {
        guard let certificate = clientCertificate else { return }

        server.update { info in
            info.connection.clientCertificate = nil
        }

        deleteCertificateIfUnreferenced(certificate)

        clientCertificate = nil
        Current.Log.info("Removed client certificate")
    }

    private func deleteCertificateIfUnreferenced(_ certificate: ClientCertificate) {
        guard !isCertificateReferenced(certificate) else {
            Current.Log.info("Keeping shared client certificate in Keychain")
            return
        }

        do {
            try ClientCertificateManager.shared.delete(certificate: certificate)
        } catch {
            Current.Log.error("Failed to delete certificate from Keychain: \(error)")
        }
    }

    private func isCertificateReferenced(_ certificate: ClientCertificate) -> Bool {
        Current.servers.all.contains { server in
            server.info.connection.clientCertificate?.keychainIdentifier == certificate.keychainIdentifier
        }
    }
}
