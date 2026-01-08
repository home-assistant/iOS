import PromiseKit
import RealmSwift
import SFSafeSymbols
import Shared
import SwiftUI
import WebKit
import XCGLogger

struct DebugView: View {
    @State private var showShareSheet = false
    @State private var logsURL: URL?
    @State private var tapsOnCasitaLogo = 0

    private let feedbackGenerator = UINotificationFeedbackGenerator()

    // Progress views
    @State private var loadingLogs = false
    @State private var loadingCleaningWebCache = false
    @State private var loadingResetApp = false

    // Alerts
    @State private var showDeleteEntitiesAlert = false
    @State private var showResetAppAlert = false
    @State private var watchSyncErrorMessage: String?
    @State private var showWatchSyncError = false

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .bugIcon,
                title: L10n.Settings.Debugging.Header.title,
                subtitle: L10n.Settings.Debugging.Header.subtitle
            )

            Section {
                Button(action: {
                    if let url = Current.Log.archiveURL() {
                        logsURL = url
                        if Current.isCatalyst {
                            if let url = Current.Log.archiveURL() {
                                URLOpener.shared.open(url, options: [:], completionHandler: nil)
                            }
                        } else {
                            loadingLogs = true
                            showShareSheet = true
                        }
                    } else {
                        Current.Log.error("Logs archive URL not available")
                    }
                }, label: {
                    linkContent(
                        image: .init(systemSymbol: .filemenuAndSelection),
                        title: Current.isCatalyst ? L10n.Settings.Developer.ShowLogFiles.title : L10n.Settings.Developer
                            .ExportLogFiles.title,
                        showProgressView: loadingLogs
                    )
                })
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

            if #available(iOS 17, *), !Current.isCatalyst {
                Section {
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
                } footer: {
                    Text(
                        L10n.Settings.Debugging.Thread.footer
                    )
                }
            }

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
                    DatabaseExplorerView()
                } label: {
                    linkContent(
                        image: .init(systemSymbol: .tablecells),
                        title: L10n.Settings.DatabaseExplorer.title
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
                    image: .init(systemSymbol: .deleteBackwardFill),
                    title: L10n.Debug.Reset.EntitiesDatabase.title,
                    iconColor: .red,
                    textColor: .red
                )
            }
            .alert(L10n.Alert.Confirmation.Generic.title, isPresented: $showDeleteEntitiesAlert) {
                Button(role: .cancel, action: { /* no-op */ }) {
                    Text(verbatim: L10n.cancelLabel)
                }
                Button(role: .destructive, action: {
                    do {
                        _ = try Current.database().write { db in
                            try HAAppEntity.deleteAll(db)
                            Current.Log.verbose("Deleted all app entities")
                        }
                    } catch {
                        Current.Log.error("Failed to reset app entities, error: \(error)")
                    }
                }) {
                    Text(verbatim: L10n.yesLabel)
                }
            } message: {
                Text(verbatim: L10n.Alert.Confirmation.DeleteEntities.message)
            }
            Button {
                loadingCleaningWebCache = true
                Current.websiteDataStoreHandler.cleanCache {
                    loadingCleaningWebCache = false
                }
            } label: {
                linkContent(
                    image: .init(systemSymbol: .deleteBackwardFill),
                    title: L10n.Settings.ResetSection.ResetWebCache.title,
                    iconColor: .red,
                    textColor: .red,
                    showProgressView: loadingCleaningWebCache
                )
            }

            Button {
                showResetAppAlert = true
            } label: {
                linkContent(
                    image: .init(systemSymbol: .deleteBackwardFill),
                    title: L10n.Settings.ResetSection.ResetApp.title,
                    iconColor: .red,
                    textColor: .red,
                    showProgressView: loadingResetApp
                )
            }
            .alert(L10n.Alert.Confirmation.Generic.title, isPresented: $showResetAppAlert) {
                Button(role: .cancel, action: { /* no-op */ }) {
                    Text(verbatim: L10n.cancelLabel)
                }
                Button(role: .destructive, action: {
                    Task {
                        await resetApp()
                    }
                }) {
                    Text(verbatim: L10n.yesLabel)
                }
            } message: {
                Text(verbatim: L10n.Settings.ResetSection.ResetAlert.title)
            }

        } footer: {
            Text(verbatim: L10n.Settings.Debugging.CriticalSection.footer)
        }
    }

    private var developerSection: some View {
        Section {
            Toggle("Toasts handled by the app", isOn: Binding(
                get: { Current.settingsStore.toastsHandledByApp },
                set: { Current.settingsStore.toastsHandledByApp = $0 }
            ))
            Button {
                if let syncError = HomeAssistantAPI.SyncWatchContext() {
                    watchSyncErrorMessage = syncError.localizedDescription
                    showWatchSyncError = true
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
                copyRealm()
            } label: {
                linkContent(
                    image: .init(systemSymbol: .docOnDoc),
                    title: L10n.Settings.Developer.CopyRealm.title
                )
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
                Text("Receive debug notifications")
            }

        } header: {
            Text(verbatim: L10n.Settings.Developer.header)
        } footer: {
            Text(verbatim: L10n.Settings.Developer.footer)
        }
    }

    private func copyRealm() {
        guard let backupURL = Realm.backup() else {
            fatalError("Unable to get Realm backup")
        }
        let containerRealmPath = Realm.Configuration.defaultConfiguration.fileURL!

        Current.Log.verbose("Would copy from \(backupURL) to \(containerRealmPath)")

        if FileManager.default.fileExists(atPath: containerRealmPath.path) {
            do {
                _ = try FileManager.default.removeItem(at: containerRealmPath)
            } catch {
                Current.Log.error("Error occurred, here are the details:\n \(error)")
            }
        }

        do {
            _ = try FileManager.default.copyItem(at: backupURL, to: containerRealmPath)
        } catch let error as NSError {
            // Catch fires here, with an NSError being thrown
            Current.Log.error("Error occurred, here are the details:\n \(error)")
        }

        let msg = L10n.Settings.Developer.CopyRealm.Alert.message(
            backupURL.path,
            containerRealmPath.path
        )
        Current.Log.verbose(msg)
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

    private func resetApp() async {
        loadingResetApp = true
        Current.Log.verbose("Resetting app!")

        for api in Current.apis {
            await revokeToken(api: api)
            await wait(seconds: 13)
            api.connection.disconnect()
        }
        for server in Current.servers.all {
            Current.servers.remove(identifier: server.identifier)
        }
        resetStores()
        setDefaults()
        await resetPushID()
        loadingResetApp = false
        Current.onboardingObservation.needed(.logout)
    }

    private func wait(seconds: Int) async {
        await Task.sleep(UInt64(seconds * 1_000_000_000))
    }

    private func revokeToken(api: HomeAssistantAPI) async {
        await withCheckedContinuation { continuation in
            api.tokenManager.revokeToken().pipe { result in
                switch result {
                case .fulfilled:
                    break
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to revoke token for api \(api.server.info.name) \(api.server.info.connection.activeURL()?.absoluteString ?? "Uknown active URL"), error: \(error.localizedDescription)"
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

#Preview {
    DebugView()
}
