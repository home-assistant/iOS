import ActivityKit
import Shared
import SwiftUI

// MARK: - Entry point

// Deployment target is iOS 15. The settings item is filtered from the list on < iOS 16.1
// (see SettingsItem.allVisibleCases), so this view is only ever navigated to on iOS 16.1+.
@available(iOS 16.1, *)
struct LiveActivitySettingsView: View {

    // MARK: State

    @State private var activities: [ActivitySnapshot] = []
    @State private var authorizationEnabled: Bool = false
    @State private var frequentUpdatesEnabled: Bool = false
    @State private var showEndAllConfirmation = false

    // MARK: Body

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .playBoxOutlineIcon,
                title: L10n.LiveActivity.title,
                subtitle: L10n.LiveActivity.subtitle
            )

            statusSection

            if activities.isEmpty {
                Section(L10n.LiveActivity.Section.active) {
                    HStack {
                        Text(L10n.LiveActivity.emptyState)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            } else {
                Section(L10n.LiveActivity.Section.active) {
                    ForEach(activities) { snapshot in
                        ActivityRow(snapshot: snapshot) {
                            endActivity(tag: snapshot.tag)
                        }
                    }

                    Button(role: .destructive) {
                        showEndAllConfirmation = true
                    } label: {
                        Label(L10n.LiveActivity.EndAll.button, systemSymbol: .xmarkCircle)
                    }
                    .confirmationDialog(
                        L10n.LiveActivity.EndAll.confirmTitle,
                        isPresented: $showEndAllConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(L10n.LiveActivity.EndAll.confirmButton, role: .destructive) {
                            endAllActivities()
                        }
                        Button(L10n.cancelLabel, role: .cancel) {}
                    }
                }
            }

            privacySection

            if #available(iOS 17.2, *) {
                frequentUpdatesSection
            }
        }
        .navigationTitle(L10n.LiveActivity.title)
        .task { await loadActivities() }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section(L10n.LiveActivity.Section.status) {
            HStack {
                Label(L10n.LiveActivity.title, systemSymbol: .livephotoIcon)
                Spacer()
                if authorizationEnabled {
                    Text(L10n.LiveActivity.Status.enabled)
                        .foregroundStyle(.green)
                } else {
                    Button(L10n.LiveActivity.Status.openSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    private var privacySection: some View {
        Section {
            Label(L10n.LiveActivity.Privacy.message, systemSymbol: .lockShieldIcon)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text(L10n.LiveActivity.Section.privacy)
        }
    }

    @available(iOS 17.2, *)
    private var frequentUpdatesSection: some View {
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Home Assistant"
        return Section {
            HStack {
                Label(L10n.LiveActivity.FrequentUpdates.title, systemSymbol: .boltIcon)
                Spacer()
                if frequentUpdatesEnabled {
                    Text(L10n.LiveActivity.Status.enabled)
                        .foregroundStyle(.green)
                } else {
                    Button(L10n.LiveActivity.Status.openSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(L10n.LiveActivity.FrequentUpdates.title)
        } footer: {
            Text(L10n.LiveActivity.FrequentUpdates.footer(appName))
        }
    }

    // MARK: - Data

    private func loadActivities() async {
        let info = ActivityAuthorizationInfo()
        authorizationEnabled = info.areActivitiesEnabled
        if #available(iOS 17.2, *) {
            frequentUpdatesEnabled = info.frequentPushesEnabled
        }

        activities = Activity<HALiveActivityAttributes>.activities.map {
            ActivitySnapshot(activity: $0)
        }
    }

    private func endActivity(tag: String) {
        Task {
            await Current.liveActivityRegistry.end(tag: tag, dismissalPolicy: .immediate)
            await loadActivities()
        }
    }

    private func endAllActivities() {
        Task {
            let tags = activities.map(\.tag)
            for tag in tags {
                await Current.liveActivityRegistry.end(tag: tag, dismissalPolicy: .immediate)
            }
            await loadActivities()
        }
    }
}

// MARK: - Activity row

@available(iOS 16.1, *)
private struct ActivityRow: View {
    let snapshot: ActivitySnapshot
    let onEnd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title)
                    .font(.body)
                Text(snapshot.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("tag: \(snapshot.tag)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button(role: .destructive, action: onEnd) {
                Image(systemSymbol: .xmarkCircleFill)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Snapshot model

@available(iOS 16.1, *)
private struct ActivitySnapshot: Identifiable {
    let id: String
    let tag: String
    let title: String
    let message: String

    init(activity: Activity<HALiveActivityAttributes>) {
        self.id = activity.id
        self.tag = activity.attributes.tag
        self.title = activity.attributes.title
        if #available(iOS 16.2, *) {
            self.message = activity.content.state.message
        } else {
            self.message = activity.contentState.message
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        if #available(iOS 16.1, *) {
            LiveActivitySettingsView()
        }
    }
}
