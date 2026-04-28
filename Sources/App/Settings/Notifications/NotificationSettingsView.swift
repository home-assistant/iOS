import PromiseKit
import Shared
import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    /// Set to `true` when presented from an in-notification "open settings" flow so we show a Done button.
    var showsDoneButton: Bool = false

    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = NotificationSettingsViewModel()

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var resetAlert: ResetAlertInfo?
    @State private var ratePromise: Promise<RateLimitResponse>?
    @State private var rateLimitRemaining: Int?

    private struct ResetAlertInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        List {
            overviewSection
            soundsSection
            badgeSection
            categoriesSection
            debugSection
        }
        .navigationTitle(L10n.SettingsDetails.Notifications.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.doneLabel) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.refreshPermissionStatus()
            if ratePromise == nil {
                let promise = NotificationRateLimitViewModel.newPromise()
                promise.done { response in
                    rateLimitRemaining = response.rateLimits.remaining
                }.cauterize()
                ratePromise = promise
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            viewModel.refreshPermissionStatus()
            viewModel.refreshBadgeCount()
        }
        .sheet(isPresented: $showShareSheet) {
            NotificationsShareSheet(activityItems: shareItems)
        }
        .alert(item: $resetAlert) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text(L10n.okLabel))
            )
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        Section {
            Text(L10n.SettingsDetails.Notifications.info)
                .foregroundColor(.primary)

            Button {
                handlePermissionTap()
            } label: {
                HStack {
                    Text(L10n.SettingsDetails.Notifications.Permission.title)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.permissionText)
                        .foregroundColor(.secondary)
                    Image(systemSymbol: .chevronRight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Link(destination: URL(string: "https://companion.home-assistant.io/app/ios/notifications")!) {
                HStack {
                    Text(L10n.SettingsDetails.learnMore)
                    Spacer()
                    Image(systemSymbol: .arrowUpForwardSquare)
                        .font(.caption)
                }
            }
        }
    }

    private var soundsSection: some View {
        Section {
            NavigationLink {
                NotificationSoundsView()
            } label: {
                Text(L10n.SettingsDetails.Notifications.Sounds.title)
            }
        } footer: {
            Text(L10n.SettingsDetails.Notifications.Sounds.footer)
        }
    }

    private var badgeSection: some View {
        Section {
            Button {
                UIApplication.shared.applicationIconBadgeNumber = 0
                viewModel.refreshBadgeCount()
            } label: {
                HStack {
                    Text(L10n.SettingsDetails.Notifications.BadgeSection.Button.title)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.badgeCountText)
                        .foregroundColor(.secondary)
                }
            }

            SwiftUI.Toggle(
                L10n.SettingsDetails.Notifications.BadgeSection.AutomaticSetting.title,
                isOn: $viewModel.clearBadgeAutomatically
            )
        } footer: {
            Text(L10n.SettingsDetails.Notifications.BadgeSection.AutomaticSetting.description)
        }
    }

    private var categoriesSection: some View {
        Section {
            NavigationLink {
                categoriesDestination
            } label: {
                Text(L10n.SettingsDetails.Notifications.Categories.header)
            }
            Text(L10n.SettingsDetails.Notifications.Categories.deprecatedNote)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var categoriesDestination: some View {
        // Category list migration is handled by the notification-categories slice.
        // Keep the existing Eureka controller until that migration lands.
        embed(NotificationCategoryListViewController())
            .navigationTitle(L10n.SettingsDetails.Notifications.Categories.header)
    }

    private var debugSection: some View {
        Section {
            NavigationLink {
                NotificationRateLimitView(initialPromise: ratePromise) { response in
                    rateLimitRemaining = response.rateLimits.remaining
                }
            } label: {
                HStack {
                    Text(L10n.SettingsDetails.Notifications.RateLimits.header)
                    Spacer()
                    if let remaining = rateLimitRemaining {
                        Text(NumberFormatter.localizedString(from: NSNumber(value: remaining), number: .decimal))
                            .foregroundColor(.secondary)
                    }
                }
            }

            NavigationLink {
                NotificationDebugNotificationsView()
            } label: {
                Text(L10n.SettingsDetails.Location.Notifications.header)
            }

            Button {
                guard let id = viewModel.pushID else { return }
                shareItems = [id]
                showShareSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.SettingsDetails.Notifications.PushIdSection.header)
                        .foregroundColor(.primary)
                    Text(viewModel.pushIDDisplay)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Button {
                viewModel.resetPushID { result in
                    switch result {
                    case .success:
                        break
                    case let .failure(error):
                        resetAlert = ResetAlertInfo(
                            title: L10n.errorLabel,
                            message: error.localizedDescription
                        )
                    }
                }
            } label: {
                Text(L10n.Settings.ResetSection.ResetRow.title)
                    .foregroundColor(.red)
            }
        } header: {
            Text(L10n.debugSectionLabel)
        }
    }

    // MARK: - Actions

    private func handlePermissionTap() {
        let wasDetermined = viewModel.lastPermissionSeen != nil && viewModel.lastPermissionSeen != .notDetermined
        UNUserNotificationCenter.current().requestAuthorization(options: .defaultOptions) { _, _ in
            Task { @MainActor in
                viewModel.refreshPermissionStatus()
                if wasDetermined {
                    URLOpener.shared.openSettings(destination: .notification, completionHandler: nil)
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct NotificationsShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - View Model

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published var permissionText: String = ""
    @Published var lastPermissionSeen: UNAuthorizationStatus?
    @Published var badgeCountText: String = ""
    // `Self` can't be referenced from a stored-property initializer in a class; use the
    // type name explicitly.
    @Published var pushIDDisplay: String = NotificationSettingsViewModel
        .displayForPushID(Current.settingsStore.pushID)
    @Published var clearBadgeAutomatically: Bool = Current.settingsStore.clearBadgeAutomatically {
        didSet {
            Current.settingsStore.clearBadgeAutomatically = clearBadgeAutomatically
        }
    }

    var pushID: String? { Current.settingsStore.pushID }

    private static func displayForPushID(_ id: String?) -> String {
        id ?? L10n.SettingsDetails.Notifications.PushIdSection.notRegistered
    }

    init() {
        refreshBadgeCount()
    }

    func refreshBadgeCount() {
        let value = UIApplication.shared.applicationIconBadgeNumber
        badgeCountText = NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    func refreshPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.lastPermissionSeen = settings.authorizationStatus
                self.permissionText = Self.permissionText(for: settings.authorizationStatus)
            }
        }
    }

    private static func permissionText(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .ephemeral, .authorized, .provisional:
            return L10n.SettingsDetails.Notifications.Permission.enabled
        case .denied:
            return L10n.SettingsDetails.Notifications.Permission.disabled
        case .notDetermined:
            return L10n.SettingsDetails.Notifications.Permission.needsRequest
        @unknown default:
            return L10n.SettingsDetails.Notifications.Permission.disabled
        }
    }

    // PromiseKit also exports a single-parameter `Result`, so qualify with `Swift.Result`.
    func resetPushID(completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        Current.Log.verbose("Resetting push token!")
        firstly {
            Current.notificationManager.resetPushID()
        }.done { [weak self] newToken in
            self?.pushIDDisplay = Self.displayForPushID(newToken)
        }.then { _ in
            when(fulfilled: Current.apis.map { $0.updateRegistration() })
        }.done { _ in
            completion(.success(()))
        }.catch { error in
            Current.Log.error("Error resetting push token: \(error)")
            completion(.failure(error))
        }
    }
}
