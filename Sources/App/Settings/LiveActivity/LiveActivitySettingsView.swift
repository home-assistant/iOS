import ActivityKit
import Shared
import SwiftUI

// MARK: - Entry point (availability wrapper)

struct LiveActivitySettingsView: View {
    var body: some View {
        if #available(iOS 16.1, *) {
            LiveActivitySettingsContentView()
        } else {
            // Unreachable in practice — the settings item is filtered out below iOS 16.1
            Text("Live Activities require iOS 16.1 or later.")
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}

// MARK: - Main content

@available(iOS 16.1, *)
private struct LiveActivitySettingsContentView: View {

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
                title: "Live Activities",
                subtitle: "Real-time Home Assistant updates on your Lock Screen and Dynamic Island."
            )

            statusSection

            if activities.isEmpty {
                Section("Active Activities") {
                    HStack {
                        Text("No active Live Activities")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            } else {
                Section("Active Activities") {
                    ForEach(activities) { snapshot in
                        ActivityRow(snapshot: snapshot) {
                            endActivity(tag: snapshot.tag)
                        }
                    }

                    Button(role: .destructive) {
                        showEndAllConfirmation = true
                    } label: {
                        Label("End All Activities", systemSymbol: .xmarkCircle)
                    }
                    .confirmationDialog(
                        "End all Live Activities?",
                        isPresented: $showEndAllConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("End All", role: .destructive) {
                            endAllActivities()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }

            privacySection

            if #available(iOS 17.2, *) {
                frequentUpdatesSection
            }
        }
        .navigationTitle("Live Activities")
        .task { await loadActivities() }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Label("Live Activities", systemSymbol: .livephotoIcon)
                Spacer()
                if authorizationEnabled {
                    Text("Enabled")
                        .foregroundStyle(.green)
                } else {
                    Button("Open Settings") {
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
            Label(
                "Live Activity content is visible on your Lock Screen and Dynamic Island without Face ID or Touch ID. Choose what you display carefully.",
                systemSymbol: .lockShieldIcon
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        } header: {
            Text("Privacy")
        }
    }

    @available(iOS 17.2, *)
    private var frequentUpdatesSection: some View {
        Section {
            HStack {
                Label("Frequent Updates", systemSymbol: .boltIcon)
                Spacer()
                if frequentUpdatesEnabled {
                    Text("Enabled")
                        .foregroundStyle(.green)
                } else {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Frequent Updates")
        } footer: {
            Text(
                "Allows Home Assistant to update Live Activities up to once per second. Enable in Settings › \(Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Home Assistant") › Live Activities."
            )
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
        LiveActivitySettingsView()
    }
}
