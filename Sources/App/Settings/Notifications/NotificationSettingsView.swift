import Shared
import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    /// Set to `true` when presented from an in-notification "open settings" flow so we show a Done button.
    var showsDoneButton: Bool = false

    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .bellIcon,
                title: L10n.SettingsDetails.Notifications.title,
                subtitle: L10n.SettingsDetails.Notifications.info
            )
            overviewSection
            historySnoozeSoundsSection
            badgeSection
        }
        .toolbar {
            // `if` directly inside `.toolbar` requires iOS 16+ ToolbarContentBuilder.
            // Move the conditional inside the item so it works on iOS 15 too.
            ToolbarItem(placement: .confirmationAction) {
                if showsDoneButton {
                    Button(L10n.doneLabel) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.refreshPermissionStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            viewModel.refreshPermissionStatus()
            viewModel.refreshBadgeCount()
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        Section {
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
                    Text(L10n.SettingsDetails.Notifications.documentation)
                    Spacer()
                    Image(systemSymbol: .arrowUpForwardSquare)
                        .font(.caption)
                }
            }
        }
    }

    private var historySnoozeSoundsSection: some View {
        Section {
            NavigationLink {
                NotificationHistoryView()
            } label: {
                Text(L10n.SettingsDetails.Notifications.History.title)
            }

            NavigationLink {
                NotificationSnoozeActionsView()
            } label: {
                Text(L10n.SettingsDetails.Notifications.SnoozeActions.header)
            }

            NavigationLink {
                NotificationSoundsView()
            } label: {
                Text(L10n.SettingsDetails.Notifications.Sounds.title)
            }
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

// MARK: - View Model

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published var permissionText: String = ""
    @Published var lastPermissionSeen: UNAuthorizationStatus?
    @Published var badgeCountText: String = ""
    @Published var clearBadgeAutomatically: Bool = Current.settingsStore.clearBadgeAutomatically {
        didSet {
            Current.settingsStore.clearBadgeAutomatically = clearBadgeAutomatically
        }
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
}
