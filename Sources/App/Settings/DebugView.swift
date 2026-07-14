import PromiseKit
import SFSafeSymbols
import Shared
import SwiftUI
import WebKit
import XCGLogger

struct DebugView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showShareSheet = false
    @State private var logsURL: URL?
    @State private var tapsOnCasitaLogo = 0
    @State private var showDeleteKeychainAlert = false
    @State private var deleteKeychainConfirmationText = ""
    @State private var deleteKeychainErrorMessage: String?
    @State private var showDeleteKeychainError = false
    @State private var showDeleteKeychainRestartAlert = false

    private let feedbackGenerator = UINotificationFeedbackGenerator()

    // Progress views
    @State private var loadingLogs = false
    @State private var loadingCleaningWebCache = false
    @State private var loadingResetApp = false
    @State private var resetAppToastMessage = ""
    @State private var resetAppToastProgress = 0

    // Alerts
    @State private var showDeleteEntitiesAlert = false
    @State private var showClearWebCacheAlert = false
    @State private var showResetAppAlert = false
    @State private var showClearAllowedTagsAlert = false
    @State private var watchSyncErrorMessage: String?
    @State private var showWatchSyncError = false

    private static let resetAppToastID = "debug-reset-app"

    private static let deleteKeychainDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .bugIcon,
                title: L10n.Settings.Debugging.Header.title,
                subtitle: L10n.Settings.Debugging.Header.subtitle
            )

            Section {
                NavigationLink {
                    ClientEventsLogView()
                } label: {
                    linkContent(image: .init(systemSymbol: .listDash), title: L10n.Settings.EventLog.title)
                }

                NavigationLink {
                    LocationHistoryListView()
                } label: {
                    linkContent(
                        image: .init(systemSymbol: .map),
                        title: L10n.Settings.LocationHistory.title
                    )
                }

                NavigationLink {
                    NotificationDebugView()
                } label: {
                    linkContent(
                        image: .init(systemSymbol: .bell),
                        title: L10n.SettingsDetails.Notifications.title
                    )
                }

                if #available(iOS 17, *), !Current.isCatalyst {
                    NavigationLink {
                        ThreadCredentialsManagementView()
                    } label: {
                        linkContent(
                            image: Image(
                                uiImage: Asset.thread.image.withRenderingMode(
                                    .alwaysTemplate
                                )
                            ),
                            title: L10n.SettingsDetails.Thread.title,
                            imageSize: 22
                        )
                    }
                }
            } footer: {
                if #available(iOS 17, *), !Current.isCatalyst {
                    Text(
                        L10n.Settings.Debugging.Thread.footer
                    )
                }
            }

            criticalSection

            if tapsOnCasitaLogo < 10 {
                Button(action: {
                    feedbackGenerator.notificationOccurred(.success)
                    tapsOnCasitaLogo += 1
                }, label: {
                    Image(uiImage: Asset.casita.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100, alignment: .center)
                })
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
            } else {
                developerSection
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportLogs()
                } label: {
                    if loadingLogs {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text(
                            Current.isCatalyst ? L10n.Settings.Developer.ShowLogFiles.title : L10n.Settings.Developer
                                .ExportLogFiles.title
                        )
                    }
                }
            }
        }
        .sheet(isPresented: .init(get: { showShareSheet && logsURL != nil }, set: { showShareSheet = $0 })) {
            if let logsURL {
                ActivityViewController(shareWrapper: .init(url: logsURL))
                    .onAppear {
                        loadingLogs = false
                    }
                    .onDisappear {
                        do {
                            try FileManager.default.removeItem(at: logsURL)
                        } catch {
                            Current.Log.error("Error deleting logs file: \(error)")
                        }
                    }
            }
        }
        .modifier(deleteKeychainAlert)
        .alert(deleteKeychainErrorMessage ?? L10n.errorLabel, isPresented: $showDeleteKeychainError) {
            Button(L10n.okLabel, role: .cancel) {
                deleteKeychainErrorMessage = nil
            }
        } message: {
            Text(deleteKeychainErrorMessage ?? "")
        }
        .alert(L10n.Settings.Debugging.KeychainRestartRequired.title, isPresented: $showDeleteKeychainRestartAlert) {
            Button(L10n.okLabel) {
                forceAppRestartAfterKeychainDeletion()
            }
        } message: {
            Text(L10n.Settings.Debugging.KeychainRestartRequired.message)
        }
    }

    private func forceAppRestartAfterKeychainDeletion() {
        #if DEBUG
        Current.Log.info("Crashing app after full keychain deletion to force restart")
        fatalError("Intentional crash after full keychain deletion to force app restart")
        #else
        Current.Log.warning("Full keychain deletion completed; app restart is required")
        #endif
    }

    private func exportLogs() {
        guard let url = Current.Log.archiveURL() else {
            Current.Log.error("Logs archive URL not available")
            return
        }

        logsURL = url
        if Current.isCatalyst {
            URLOpener.shared.open(url, options: [:], completionHandler: nil)
        } else {
            loadingLogs = true
            showShareSheet = true
        }
    }

    private var deleteKeychainAlert: some ViewModifier {
        DeleteKeychainAlertModifier(
            isPresented: $showDeleteKeychainAlert,
            confirmationText: $deleteKeychainConfirmationText,
            errorMessage: $deleteKeychainErrorMessage,
            showError: $showDeleteKeychainError,
            currentConfirmationDate: currentConfirmationDate,
            feedbackGenerator: feedbackGenerator,
            onDeleteSuccess: {
                DispatchQueue.main.async {
                    showDeleteKeychainRestartAlert = true
                }
            }
        )
    }

    private func linkContent(
        image: Image,
        title: String,
        imageSize: CGFloat = 18,
        iconColor: Color = Color.haPrimary,
        textColor: Color = Color(uiColor: .label),
        showProgressView: Bool? = nil
    ) -> some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize, alignment: .center)
                .foregroundStyle(iconColor)
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(textColor)
            if let showProgressView {
                ProgressView()
                    .progressViewStyle(.circular)
                    .opacity(showProgressView ? 1 : 0)
                    .animation(.easeOut(duration: 2), value: showProgressView)
            }
        }
    }

    private var criticalSection: some View {
        Section {
            Button {
                showDeleteEntitiesAlert = true
            } label: {
                linkContent(
                    image: .init(systemSymbol: .tablecells),
                    title: L10n.Settings.Debugging.CachedEntityData.title,
                    iconColor: .red,
                    textColor: .red
                )
            }
            .alert(L10n.Settings.Debugging.CachedEntityData.alertTitle, isPresented: $showDeleteEntitiesAlert) {
                Button(L10n.cancelLabel, role: .cancel) {}
                Button(L10n.Settings.Debugging.CachedEntityData.deleteButton, role: .destructive) {
                    do {
                        _ = try Current.database().write { db in
                            try HAAppEntity.deleteAll(db)
                            Current.Log.verbose("Deleted all app entities")
                        }
                    } catch {
                        Current.Log.error("Failed to reset app entities, error: \(error)")
                    }
                }
            } message: {
                Text(
                    L10n.Settings.Debugging.CachedEntityData.message
                )
            }

            Button {
                showClearWebCacheAlert = true
            } label: {
                linkContent(
                    image: .init(systemSymbol: .globe),
                    title: L10n.Settings.Debugging.ClearWebCache.title,
                    iconColor: .red,
                    textColor: .red,
                    showProgressView: loadingCleaningWebCache
                )
            }
            .alert(L10n.Settings.Debugging.ClearWebCache.alertTitle, isPresented: $showClearWebCacheAlert) {
                Button(L10n.cancelLabel, role: .cancel) {}
                Button(L10n.Settings.Debugging.ClearWebCache.clearButton, role: .destructive) {
                    loadingCleaningWebCache = true
                    Current.websiteDataStoreHandler.cleanCache {
                        loadingCleaningWebCache = false
                    }
                }
            } message: {
                Text(
                    L10n.Settings.Debugging.ClearWebCache.message
                )
            }

            Button {
                showResetAppAlert = true
            } label: {
                linkContent(
                    image: .init(systemSymbol: .exclamationmarkTriangle),
                    title: L10n.Settings.Debugging.ResetApp.title,
                    iconColor: .red,
                    textColor: .red,
                    showProgressView: loadingResetApp
                )
            }
            .alert(L10n.Settings.Debugging.ResetApp.alertTitle, isPresented: $showResetAppAlert) {
                Button(L10n.cancelLabel, role: .cancel) {}
                Button(L10n.Settings.Debugging.ResetApp.deleteButton, role: .destructive) {
                    Task {
                        await resetApp()
                    }
                }
            } message: {
                Text(L10n.Settings.Debugging.ResetApp.message)
            }

        } footer: {
            Text(verbatim: L10n.Settings.Debugging.CriticalSection.footer)
        }
    }

    private var carPlayDebugSection: some View {
        NavigationLink {
            CarPlayDebugSettingsView()
        } label: {
            linkContent(
                image: .init(systemSymbol: .carFill),
                title: L10n.CarPlay.Debug.Settings.rowTitle
            )
        }
    }

    private var developerSection: some View {
        Section {
            #if DEBUG
            NavigationLink {
                ComponentsLibraryView()
            } label: {
                linkContent(
                    image: .init(systemSymbol: .paintpalette),
                    title: L10n.Settings.Debugging.ComponentsLibrary.title
                )
            }
            #endif

            NavigationLink {
                MediaTypesRequiringUserActionForPlaybackView()
            } label: {
                linkContent(
                    image: .init(systemSymbol: .speakerWave2Fill),
                    title: L10n.Settings.Debugging.MediaPlayback.title
                )
            }

            NavigationLink {
                DatabaseExplorerView()
            } label: {
                linkContent(
                    image: .init(systemSymbol: .tablecells),
                    title: L10n.Settings.DatabaseExplorer.title
                )
            }

            #if DEBUG
            NavigationLink {
                KeychainExplorerView()
            } label: {
                linkContent(
                    image: .init(systemSymbol: .key),
                    title: L10n.Settings.Debugging.KeychainExplorer.title
                )
            }
            #endif

            carPlayDebugSection

            Button {
                Task { @MainActor in
                    if let syncError = await HomeAssistantAPI.SyncWatchContext() {
                        watchSyncErrorMessage = syncError.localizedDescription
                        showWatchSyncError = true
                    }
                }
            } label: {
                linkContent(
                    image: .init(systemSymbol: .applewatchWatchface),
                    title: L10n.Settings.Developer.SyncWatchContext.title
                )
            }
            .alert(L10n.errorLabel, isPresented: $showWatchSyncError) {
                Button(role: .cancel, action: { /* no-op */ }) {
                    Text(verbatim: L10n.okLabel)
                }
            } message: {
                Text(watchSyncErrorMessage.orEmpty)
            }

            Button {
                prefs.set(!prefs.bool(forKey: "showTranslationKeys"), forKey: "showTranslationKeys")
            } label: {
                linkContent(
                    image: .init(systemSymbol: .textBubble),
                    title: L10n.Settings.Developer.DebugStrings.title
                )
            }

            Button {
                sendCameraNotification()
            } label: {
                linkContent(
                    image: .init(systemSymbol: .camera),
                    title: L10n.Settings.Developer.CameraNotification.title
                )
            }

            Button {
                sendMapNotification()
            } label: {
                linkContent(
                    image: .init(systemSymbol: .map),
                    title: L10n.Settings.Developer.MapNotification.title
                )
            }

            Button {
                showClearAllowedTagsAlert = true
            } label: {
                linkContent(
                    image: .init(systemSymbol: .tag),
                    title: L10n.Settings.Debugging.ClearAllowedTags.title,
                    iconColor: .red,
                    textColor: .red
                )
            }
            .alert(L10n.Settings.Debugging.ClearAllowedTags.alertTitle, isPresented: $showClearAllowedTagsAlert) {
                Button(L10n.cancelLabel, role: .cancel) {}
                Button(L10n.Settings.Debugging.ClearAllowedTags.clearButton, role: .destructive) {
                    AllowedTag.clearAll()
                }
            } message: {
                Text(
                    L10n.Settings.Debugging.ClearAllowedTags.message
                )
            }

            Button {
                deleteKeychainConfirmationText = ""
                showDeleteKeychainAlert = true
            } label: {
                linkContent(
                    image: .init(systemSymbol: .key),
                    title: L10n.Settings.Debugging.DeleteSavedCredentials.title,
                    iconColor: .red,
                    textColor: .red
                )
            }

            Toggle(isOn: .init(get: {
                prefs.bool(forKey: XCGLogger.shouldNotifyUserDefaultsKey)
            }, set: { newValue in
                prefs.set(newValue, forKey: XCGLogger.shouldNotifyUserDefaultsKey)

            })) {
                linkContent(
                    image: .init(systemSymbol: .info),
                    title: L10n.Settings.Developer.AnnoyingBackgroundNotifications.title
                )
            }

            Toggle(isOn: .init(get: {
                Current.settingsStore.receiveDebugNotifications
            }, set: { newValue in
                Current.settingsStore.receiveDebugNotifications = newValue
            })) {
                Text(L10n.Settings.Debugging.ReceiveDebugNotifications.title)
            }

            Picker(selection: Binding(
                get: { Current.settingsStore.webViewEmptyStateTimeout },
                set: { Current.settingsStore.webViewEmptyStateTimeout = $0 }
            )) {
                ForEach([5, 10, 15, 20, 30, 60], id: \.self) { seconds in
                    Text(verbatim: "\(seconds)s").tag(seconds)
                }
            } label: {
                Text(L10n.Settings.Debugging.WebViewEmptyStateTimeout.title)
            }
            .pickerStyle(.menu)

        } header: {
            Text(verbatim: L10n.Settings.Developer.header)
        } footer: {
            Text(verbatim: L10n.Settings.Developer.footer)
        }
    }

    private func sendMapNotification() {
        let content = UNMutableNotificationContent()
        content.body = L10n.Settings.Developer.MapNotification.Notification.body
        content.sound = .default

        var firstPinLatitude = "40.785091"
        var firstPinLongitude = "-73.968285"

        // swiftlint:disable prohibit_environment_assignment
        if Current.appConfiguration == .fastlaneSnapshot,
           let lat = prefs.string(forKey: "mapPin1Latitude"),
           let lon = prefs.string(forKey: "mapPin1Longitude") {
            firstPinLatitude = lat
            firstPinLongitude = lon
        }

        var secondPinLatitude = "40.758896"
        var secondPinLongitude = "-73.985130"

        if Current.appConfiguration == .fastlaneSnapshot,
           let lat = prefs.string(forKey: "mapPin2Latitude"),
           let lon = prefs.string(forKey: "mapPin2Longitude") {
            secondPinLatitude = lat
            secondPinLongitude = lon
        }
        // swiftlint:enable prohibit_environment_assignment

        content.userInfo = [
            "homeassistant": [
                "latitude": firstPinLatitude,
                "longitude": firstPinLongitude,
                "second_latitude": secondPinLatitude,
                "second_longitude": secondPinLongitude,
            ],
        ]
        content.categoryIdentifier = "map"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let notificationRequest = UNNotificationRequest(
            identifier: "mapContentExtension",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(notificationRequest)
    }

    private func sendCameraNotification() {
        let content = UNMutableNotificationContent()
        content.body = L10n.Settings.Developer.CameraNotification.Notification.body
        content.sound = .default

        var entityID = "camera.amcrest_camera"

        if Current.appConfiguration == .fastlaneSnapshot,
           let snapshotEntityID = prefs.string(forKey: "cameraEntityID") {
            entityID = snapshotEntityID
        }

        content.userInfo = ["entity_id": entityID]
        content.categoryIdentifier = "camera"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let notificationRequest = UNNotificationRequest(
            identifier: "cameraContentExtension",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(notificationRequest)
    }

    private var currentConfirmationDate: String {
        Self.deleteKeychainDateFormatter.string(from: Date())
    }

    @MainActor
    private func resetApp() async {
        loadingResetApp = true
        resetAppToastMessage = L10n.Settings.Debugging.ResetApp.Toast.preparing
        resetAppToastProgress = 0
        let toastProgressTask = Task { @MainActor in
            await showResetAppToastProgress()
        }
        async let minimumToastDuration: Void = wait(seconds: 3)

        Current.Log.verbose("Resetting app!")

        for api in Current.apis {
            resetAppToastMessage = L10n.Settings.Debugging.ResetApp.Toast.revokingToken(api.server.info.name)
            await revokeToken(api: api)
            resetAppToastMessage = L10n.Settings.Debugging.ResetApp.Toast.disconnecting(api.server.info.name)
            await wait(seconds: 13)
            api.connection.disconnect()
        }
        resetAppToastMessage = L10n.Settings.Debugging.ResetApp.Toast.removingServers
        for server in Current.servers.all {
            Current.servers.remove(identifier: server.identifier)
        }
        resetAppToastMessage = L10n.Settings.Debugging.ResetApp.Toast.clearingDatabases
        resetStores()
        setDefaults()
        resetAppToastMessage = L10n.Settings.Debugging.ResetApp.Toast.resettingPushRegistration
        await resetPushID()
        resetAppToastMessage = L10n.Settings.Debugging.ResetApp.Toast.finishing
        await minimumToastDuration
        toastProgressTask.cancel()
        await toastProgressTask.value
        hideResetAppToast()
        loadingResetApp = false
        dismissSettingsAfterReset()
        Current.onboardingObservation.needed(.logout)
    }

    @MainActor
    private func showResetAppToastProgress() async {
        while !Task.isCancelled {
            showResetAppToast(
                message: L10n.Settings.Debugging.ResetApp.Toast.progress(resetAppToastMessage, resetAppToastProgress)
            )
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            resetAppToastProgress = min(resetAppToastProgress + 2, 98)
        }
    }

    private func showResetAppToast(message: String) {
        if #available(iOS 18, *) {
            ToastPresenter.shared.show(
                id: Self.resetAppToastID,
                symbol: .exclamationmarkTriangle,
                symbolForegroundStyle: (.white, .red),
                title: L10n.Settings.Debugging.ResetApp.Toast.title,
                message: message
            )
        }
    }

    private func hideResetAppToast() {
        if #available(iOS 18, *) {
            ToastPresenter.shared.hide(id: Self.resetAppToastID)
        }
    }

    private func dismissSettingsAfterReset() {
        AppSettingsPresenter.shared.isSheetPresented = false
        AppSettingsPresenter.shared.isPushPresented = false
        dismiss()
    }

    private func wait(seconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func revokeToken(api: HomeAssistantAPI) async {
        let activeURLString = await api.server.activeURL()?.absoluteString ?? "Uknown active URL"
        await withCheckedContinuation { continuation in
            api.tokenManager.revokeToken().pipe { result in
                switch result {
                case .fulfilled:
                    break
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to revoke token for api \(api.server.info.name) \(activeURLString), error: \(error.localizedDescription)"
                        )
                }
                continuation.resume()
            }
        }
    }

    private func resetPushID() async {
        await withCheckedContinuation { continuation in
            Current.notificationManager.resetPushID().pipe { result in
                switch result {
                case .fulfilled:
                    break
                case let .rejected(error):
                    Current.Log.error("Failed to reset push ID, error: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }
}

private struct MediaTypesRequiringUserActionForPlaybackView: View {
    @State private var selectedMediaTypes: Set<SettingsStore.MediaTypeRequiringUserActionForPlayback>
    @State private var showRestartAlert = false

    init() {
        _selectedMediaTypes = State(initialValue: Current.settingsStore.mediaTypesRequiringUserActionForPlayback)
    }

    var body: some View {
        List {
            Section {
                ForEach(SettingsStore.MediaTypeRequiringUserActionForPlayback.allCases, id: \.self) { mediaType in
                    Button {
                        toggle(mediaType)
                    } label: {
                        HStack {
                            Text(mediaType.title)
                            Spacer()
                            if selectedMediaTypes.contains(mediaType) {
                                Image(systemSymbol: .checkmark)
                                    .foregroundStyle(Color.haPrimary)
                            }
                        }
                    }
                    .foregroundStyle(Color(uiColor: .label))
                }
            } footer: {
                Text(L10n.Settings.Debugging.MediaPlayback.footer)
            }
        }
        .navigationTitle(L10n.Settings.Debugging.MediaPlayback.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.Settings.Debugging.MediaPlayback.RestartRequired.title, isPresented: $showRestartAlert) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.Debugging.MediaPlayback.RestartRequired.message)
        }
    }

    private func toggle(_ mediaType: SettingsStore.MediaTypeRequiringUserActionForPlayback) {
        if selectedMediaTypes.contains(mediaType) {
            selectedMediaTypes.remove(mediaType)
        } else {
            selectedMediaTypes.insert(mediaType)
        }

        Current.settingsStore.mediaTypesRequiringUserActionForPlayback = selectedMediaTypes
        showRestartAlert = true
    }
}

private struct CarPlayDebugSettingsView: View {
    @State private var settings: CarPlayAssistDebugSettings
    @State private var showResetConfirmation = false

    init() {
        _settings = State(initialValue: Current.settingsStore.carPlayAssistDebugSettings)
    }

    var body: some View {
        List {
            assistSessionSection
            ttsPlaybackSection
            ttsSessionSection
            resetSection
        }
        .navigationTitle(L10n.CarPlay.Debug.Settings.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { updatedSettings in
            Current.settingsStore.carPlayAssistDebugSettings = updatedSettings
        }
    }

    private var assistSessionSection: some View {
        Section {
            Picker(L10n.CarPlay.Debug.Settings.AssistSession.audioCategory, selection: $settings.audioCategory) {
                ForEach(CarPlayAssistAudioCategory.allCases, id: \.self) { category in
                    Text(category.title).tag(category)
                }
            }

            Picker(L10n.CarPlay.Debug.Settings.AssistSession.audioMode, selection: $settings.audioMode) {
                ForEach(CarPlayAssistAudioMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Picker(
                L10n.CarPlay.Debug.Settings.AssistSession.preferredSampleRate,
                selection: $settings.preferredSampleRate
            ) {
                ForEach(CarPlayAssistPreferredSampleRate.allCases, id: \.self) { sampleRate in
                    Text(sampleRate.title).tag(sampleRate)
                }
            }

            Toggle(L10n.CarPlay.Debug.Settings.AssistSession.allowBluetoothHfp, isOn: $settings.allowBluetoothHFP)
            Toggle(L10n.CarPlay.Debug.Settings.AssistSession.allowBluetoothA2dp, isOn: $settings.allowBluetoothA2DP)
            Toggle(L10n.CarPlay.Debug.Settings.AssistSession.duckOthers, isOn: $settings.duckOthers)
            Toggle(L10n.CarPlay.Debug.Settings.AssistSession.interruptSpokenAudio, isOn: $settings.interruptSpokenAudio)
            Toggle(
                L10n.CarPlay.Debug.Settings.AssistSession.recorderManagesAudioSession,
                isOn: $settings.recorderManagesAudioSession
            )
            Toggle(
                L10n.CarPlay.Debug.Settings.AssistSession.playRecordingIndicatorTone,
                isOn: $settings.playRecordingIndicatorTone
            )
        } header: {
            Text(L10n.CarPlay.Debug.Settings.AssistSession.title)
        } footer: {
            Text(L10n.CarPlay.Debug.Settings.AssistSession.footer)
        }
    }

    private var ttsPlaybackSection: some View {
        Section {
            Picker(L10n.CarPlay.Debug.Settings.TtsPlayback.playbackStrategy, selection: $settings.ttsPlaybackStrategy) {
                ForEach(CarPlayAssistTTSPlaybackStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.title).tag(strategy)
                }
            }

            Picker(L10n.CarPlay.Debug.Settings.TtsPlayback.playbackDelay, selection: $settings.ttsPlaybackDelay) {
                ForEach(CarPlayAssistPlaybackDelay.allCases, id: \.self) { delay in
                    Text(delay.title).tag(delay)
                }
            }

            Toggle(
                L10n.CarPlay.Debug.Settings.TtsPlayback.avplayerWaitsToMinimizeStalling,
                isOn: $settings.avPlayerAutomaticallyWaitsToMinimizeStalling
            )
        } header: {
            Text(L10n.CarPlay.Debug.Settings.TtsPlayback.title)
        } footer: {
            Text(L10n.CarPlay.Debug.Settings.TtsPlayback.footer)
        }
    }

    private var ttsSessionSection: some View {
        Section {
            Toggle(
                L10n.CarPlay.Debug.Settings.TtsAudioSession.reconfigureBeforeTts,
                isOn: $settings.ttsReconfigureAudioSession
            )
            Toggle(
                L10n.CarPlay.Debug.Settings.TtsAudioSession.deactivateBeforeReconfigure,
                isOn: $settings.ttsDeactivateBeforeReconfigure
            )
            Toggle(
                L10n.CarPlay.Debug.Settings.TtsAudioSession.activateAudioSessionBeforePlay,
                isOn: $settings.ttsActivateAudioSession
            )

            Picker(L10n.CarPlay.Debug.Settings.TtsAudioSession.category, selection: $settings.ttsCategory) {
                ForEach(CarPlayAssistAudioCategory.allCases, id: \.self) { category in
                    Text(category.title).tag(category)
                }
            }

            Picker(L10n.CarPlay.Debug.Settings.TtsAudioSession.mode, selection: $settings.ttsMode) {
                ForEach(CarPlayAssistAudioMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Toggle(L10n.CarPlay.Debug.Settings.TtsAudioSession.allowBluetoothHfp, isOn: $settings.ttsAllowBluetoothHFP)
            Toggle(
                L10n.CarPlay.Debug.Settings.TtsAudioSession.allowBluetoothA2dp,
                isOn: $settings.ttsAllowBluetoothA2DP
            )
            Toggle(L10n.CarPlay.Debug.Settings.TtsAudioSession.duckOthers, isOn: $settings.ttsDuckOthers)
            Toggle(
                L10n.CarPlay.Debug.Settings.TtsAudioSession.interruptSpokenAudio,
                isOn: $settings.ttsInterruptSpokenAudio
            )
        } header: {
            Text(L10n.CarPlay.Debug.Settings.TtsAudioSession.title)
        } footer: {
            Text(L10n.CarPlay.Debug.Settings.TtsAudioSession.footer)
        }
    }

    private var resetSection: some View {
        Section {
            Button(L10n.CarPlay.Debug.Settings.reset, role: .destructive) {
                showResetConfirmation = true
            }
            .confirmationDialog(
                L10n.Alert.Confirmation.Generic.title,
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.CarPlay.Debug.Settings.reset, role: .destructive) {
                    settings = .default
                }
                Button(L10n.cancelLabel, role: .cancel) {}
            }
        }
    }
}

private struct DeleteKeychainAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var confirmationText: String
    @Binding var errorMessage: String?
    @Binding var showError: Bool

    let currentConfirmationDate: String
    let feedbackGenerator: UINotificationFeedbackGenerator
    let onDeleteSuccess: () -> Void

    func body(content: Content) -> some View {
        content.alert(L10n.Settings.Debugging.DeleteSavedCredentials.alertTitle, isPresented: $isPresented) {
            TextField(L10n.Settings.Debugging.DeleteKeychain.datePlaceholder, text: $confirmationText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button(L10n.cancelLabel, role: .cancel) {
                confirmationText = ""
            }
            Button(L10n.Settings.Debugging.DeleteSavedCredentials.deleteButton, role: .destructive) {
                guard confirmationText == currentConfirmationDate else {
                    errorMessage = L10n.Settings.Debugging.DeleteKeychain.invalidDateFormat(currentConfirmationDate)
                    showError = true
                    return
                }

                do {
                    try deleteKeychainCompletely()
                    feedbackGenerator.notificationOccurred(.success)
                    onDeleteSuccess()
                } catch {
                    Current.Log.error("Failed to delete keychain completely: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    showError = true
                }

                confirmationText = ""
            }
        } message: {
            Text(
                L10n.Settings.Debugging.DeleteSavedCredentials.message(currentConfirmationDate)
            )
        }
    }
}

#Preview {
    DebugView()
}
