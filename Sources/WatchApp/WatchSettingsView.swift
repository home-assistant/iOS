import SFSafeSymbols
import Shared
import SwiftUI

/// Watch settings. Lists servers synchronized from the paired iPhone and shows connectivity details
/// (including mTLS client-certificate status). It also provides watch-local preferences like where
/// actions run (iPhone vs Watch) and per-server URL overrides; server configuration itself remains
/// managed on the iPhone.
struct WatchSettingsView: View {
    @StateObject private var viewModel = WatchSettingsViewModel()
    @State private var performActionTarget = WatchUserDefaults.shared.performActionTarget
    /// Developer option: routing is always automatic unless this re-enables the picker. Refreshed
    /// on appear so toggling it in the Developer screen reflects here on pop.
    @State private var allowChoosingRoute = WatchUserDefaults.shared.allowChoosingMagicItemRoute
    @State private var showDeleteLocalDataConfirmation = false
    @State private var showDeleteLocalDataResult = false
    @State private var deleteLocalDataSucceeded = false

    var body: some View {
        NavigationView {
            List {
                serversSection
                networkSection
                configurationSection
                layoutSection
                if allowChoosingRoute {
                    performActionSection
                }
                troubleshootingSection
                deleteLocalDataSection
                restartAppSection
            }
            .onAppear {
                allowChoosingRoute = WatchUserDefaults.shared.allowChoosingMagicItemRoute
                performActionTarget = WatchUserDefaults.shared.performActionTarget
            }
            .navigationTitle(Text(verbatim: L10n.Watch.Settings.title))
            .alert(
                Text(
                    verbatim: deleteLocalDataSucceeded
                        ? L10n.Watch.Settings.DeleteLocalData.success
                        : L10n.Watch.Settings.DeleteLocalData.error
                ),
                isPresented: $showDeleteLocalDataResult
            ) {
                Button(role: .cancel) {} label: { Text(verbatim: L10n.okLabel) }
            }
        }
    }

    private var deleteLocalDataSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteLocalDataConfirmation = true
            } label: {
                Label(L10n.Watch.Settings.DeleteLocalData.title, systemSymbol: .trash)
            }
            .alert(
                Text(verbatim: L10n.Watch.Settings.DeleteLocalData.Confirm.title),
                isPresented: $showDeleteLocalDataConfirmation
            ) {
                Button(role: .cancel) {} label: { Text(verbatim: L10n.cancelLabel) }
                Button(role: .destructive) {
                    deleteLocalDataSucceeded = viewModel.deleteLocalData()
                    showDeleteLocalDataResult = true
                } label: {
                    Text(verbatim: L10n.Watch.Settings.DeleteLocalData.Confirm.delete)
                }
            } message: {
                Text(verbatim: L10n.Watch.Settings.DeleteLocalData.Confirm.message)
            }
        } footer: {
            Text(verbatim: L10n.Watch.Settings.DeleteLocalData.footer)
        }
    }

    private var configurationSection: some View {
        Section {
            NavigationLink {
                WatchConfigAssistView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                        Text(verbatim: L10n.Watch.Config.Assist.title)
                        Text(verbatim: viewModel.assistPipelineTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemSymbol: .waveformCircleFill)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchConfigDidChange)) { _ in
                viewModel.reload()
            }
        }
    }

    private var layoutSection: some View {
        Section {
            Picker(L10n.Watch.Configuration.Layout.title, selection: Binding(
                get: { viewModel.layout },
                set: { viewModel.updateLayout($0) }
            )) {
                ForEach(WatchLayout.allCases, id: \.rawValue) { layout in
                    Text(verbatim: layout.name).tag(layout)
                }
            }
        } footer: {
            Text(verbatim: L10n.Watch.Configuration.Layout.footer)
        }
    }

    private var performActionSection: some View {
        Section {
            Picker(L10n.Watch.Settings.PerformAction.title, selection: $performActionTarget) {
                Text(verbatim: L10n.Watch.Settings.auto).tag(WatchActionTarget.auto)
                Text(verbatim: L10n.Watch.Settings.PerformAction.iphone).tag(WatchActionTarget.iPhone)
                Text(verbatim: L10n.Watch.Settings.PerformAction.appleWatch).tag(WatchActionTarget.appleWatch)
            }
            .onChange(of: performActionTarget) { newValue in
                WatchUserDefaults.shared.performActionTarget = newValue
            }
        } footer: {
            Text(verbatim: L10n.Watch.Settings.PerformAction.footerPreferWatch)
        }
    }

    private var troubleshootingSection: some View {
        Section {
            NavigationLink {
                WatchTroubleshootingView()
            } label: {
                Label(L10n.Watch.Settings.Troubleshooting.title, systemSymbol: .stethoscope)
            }
        }
    }

    private var restartAppSection: some View {
        Section {
            Button(role: .destructive) {
                // Terminate cleanly (watchOS relaunches on next tap). A `fatalError` here would file a
                // crash report for every use — it was one of the app's top "crashes" in the field.
                exit(0)
            } label: {
                Label(L10n.Watch.Settings.RestartApp.title, systemSymbol: .arrowClockwise)
            }
        } footer: {
            Text(verbatim: L10n.Watch.Settings.RestartApp.footer)
        }
    }

    /// The Wi-Fi network the watch is currently on. Hidden when there's no SSID (e.g. on LTE).
    @ViewBuilder
    private var networkSection: some View {
        if !viewModel.currentSSID.isEmpty {
            Section {
                Label {
                    Text(verbatim: viewModel.currentSSID)
                        .minimumScaleFactor(0.5)
                } icon: {
                    Image(systemSymbol: .wifi)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var serversSection: some View {
        Section {
            if viewModel.servers.isEmpty {
                Text(verbatim: L10n.Watch.Settings.noServers)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                // Small screen: group servers behind one link; the full list is one tap away.
                NavigationLink {
                    WatchServersListView(viewModel: viewModel)
                } label: {
                    Label {
                        Text(verbatim: L10n.Watch.Settings.Servers.header)
                    } icon: {
                        Image(systemSymbol: .network)
                    }
                }
            }
        } footer: {
            // When the synchronized data is from — refreshed via the Home screen's reload button.
            if let lastUpdated = viewModel.lastUpdated {
                Text(verbatim: L10n.Watch.Settings.lastUpdated(
                    lastUpdated.formatted(date: .abbreviated, time: .shortened)
                ))
            }
        }
    }
}

/// The list of synchronized servers, pushed from the settings "Servers" row so the small settings
/// screen stays compact. Each server opens its read-only detail.
private struct WatchServersListView: View {
    @ObservedObject var viewModel: WatchSettingsViewModel

    var body: some View {
        List {
            ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                NavigationLink {
                    WatchServerDetailView(server: server)
                } label: {
                    Label {
                        Text(verbatim: server.info.name)
                    } icon: {
                        Image(systemSymbol: .network)
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Servers.header))
    }
}

/// Explains that the iPhone/Watch link can get stuck and that rebooting both devices usually helps.
private struct WatchTroubleshootingView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                    Label(
                        L10n.Watch.Settings.Troubleshooting.Connection.title,
                        systemSymbol: .antennaRadiowavesLeftAndRight
                    )
                    .font(.headline)
                    Text(verbatim: L10n.Watch.Settings.Troubleshooting.Connection.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, DesignSystem.Spaces.half)
            }

            Section {
                NavigationLink {
                    WatchComplicationsDiagnosticsView()
                } label: {
                    Label(L10n.Watch.Settings.Complications.title, systemSymbol: .clockArrowCirclepath)
                }
                NavigationLink {
                    WatchClientEventsView()
                } label: {
                    Label(L10n.Watch.Settings.ClientEvents.title, systemSymbol: .listBulletRectangle)
                }
            }

            Section {
                NavigationLink {
                    WatchDeveloperSettingsView()
                } label: {
                    Label(L10n.Watch.Settings.Developer.title, systemSymbol: .hammer)
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Troubleshooting.title))
    }
}

/// Shared status → icon/color/text mapping for complication refresh diagnostics.
enum ComplicationDiagnosticStyle {
    static func icon(for status: ComplicationRefreshOutcome.Status?) -> SFSymbol {
        switch status {
        case .live: return .checkmarkCircleFill
        case .cached: return .clockArrowCirclepath
        case .failed: return .exclamationmarkTriangleFill
        case .none: return .questionmarkCircle
        }
    }

    static func color(for status: ComplicationRefreshOutcome.Status?) -> Color {
        switch status {
        case .live: return .green
        case .cached: return .orange
        case .failed: return .red
        case .none: return .secondary
        }
    }

    static func text(for status: ComplicationRefreshOutcome.Status?) -> String {
        switch status {
        case .live: return L10n.Watch.Settings.Complications.Status.live
        case .cached: return L10n.Watch.Settings.Complications.Status.cached
        case .failed: return L10n.Watch.Settings.Complications.Status.failed
        case .none: return L10n.Watch.Settings.Complications.never
        }
    }
}

/// On-device complication diagnostics: lists each configured complication with its last refresh
/// status, and lets you refresh them all. Each row opens a detail with the last-attempt time, reason,
/// and a per-complication retry — so connectivity issues are visible and fixable without the iPhone.
private struct WatchComplicationsDiagnosticsView: View {
    @State private var configs: [WatchComplicationConfig] = []
    @State private var records: [String: ComplicationRefreshRecord] = [:]
    @State private var isRefreshingAll = false

    var body: some View {
        List {
            Section {
                Button {
                    Task { await refreshAll() }
                } label: {
                    if isRefreshingAll {
                        // A live spinner so a slow REST refresh doesn't look stuck (feedback: "seems frozen").
                        HStack(spacing: DesignSystem.Spaces.one) {
                            ProgressView()
                            Text(verbatim: L10n.Watch.Settings.Complications.refreshing)
                        }
                    } else {
                        Label(L10n.Watch.Settings.Complications.refreshAll, systemSymbol: .arrowClockwise)
                    }
                }
                .disabled(isRefreshingAll || configs.isEmpty)
            } footer: {
                Text(verbatim: L10n.Watch.Settings.Complications.footer)
            }

            if configs.isEmpty {
                Text(verbatim: L10n.Watch.Settings.Complications.empty)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(configs) { config in
                        NavigationLink {
                            ComplicationDiagnosticDetailView(config: config)
                        } label: {
                            row(for: config)
                        }
                    }
                } footer: {
                    Text(verbatim: L10n.Watch.Settings.Complications.listFooter)
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Complications.title))
        .onAppear(perform: load)
    }

    private func row(for config: WatchComplicationConfig) -> some View {
        let record = records[config.id]
        return VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Label {
                Text(verbatim: config.displayName)
            } icon: {
                Image(systemSymbol: ComplicationDiagnosticStyle.icon(for: record?.status))
                    .foregroundStyle(ComplicationDiagnosticStyle.color(for: record?.status))
            }
            Text(verbatim: subtitle(for: record))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignSystem.Spaces.half)
    }

    private func subtitle(for record: ComplicationRefreshRecord?) -> String {
        guard let record else { return L10n.Watch.Settings.Complications.never }
        return ComplicationDiagnosticStyle.text(for: record.status)
    }

    private func load() {
        configs = (try? WatchComplicationConfig.all()) ?? []
        records = WatchWidgetComplicationSnapshotStore.records()
    }

    @MainActor
    private func refreshAll() async {
        isRefreshingAll = true
        _ = await WatchWidgetComplicationSnapshotStore.refresh()
        records = WatchWidgetComplicationSnapshotStore.records()
        isRefreshingAll = false
    }
}

/// Per-complication diagnostics detail: when it last tried to update, whether it worked, why not, and
/// a Retry button that re-fetches just this complication and updates the screen with the new result.
private struct ComplicationDiagnosticDetailView: View {
    let config: WatchComplicationConfig
    @State private var record: ComplicationRefreshRecord?
    @State private var isRetrying = false

    var body: some View {
        List {
            Section {
                Label {
                    Text(verbatim: ComplicationDiagnosticStyle.text(for: record?.status))
                } icon: {
                    Image(systemSymbol: ComplicationDiagnosticStyle.icon(for: record?.status))
                        .foregroundStyle(ComplicationDiagnosticStyle.color(for: record?.status))
                }
                Text(verbatim: lastAttemptText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(verbatim: L10n.Watch.Settings.Complications.statusHeader)
            }

            if let reason = record?.reason, !reason.isEmpty {
                Section {
                    Text(verbatim: reason)
                        .font(.footnote)
                } header: {
                    Text(verbatim: L10n.Watch.Settings.Complications.reasonHeader)
                }
            }

            Section {
                Button {
                    Task { await retry() }
                } label: {
                    if isRetrying {
                        HStack(spacing: DesignSystem.Spaces.one) {
                            ProgressView()
                            Text(verbatim: L10n.Watch.Settings.Complications.retrying)
                        }
                    } else {
                        Label(L10n.Watch.Settings.Complications.retry, systemSymbol: .arrowClockwise)
                    }
                }
                .disabled(isRetrying)
            }
        }
        .navigationTitle(Text(verbatim: config.displayName))
        .onAppear {
            record = WatchWidgetComplicationSnapshotStore.records()[config.id]
        }
    }

    private var lastAttemptText: String {
        guard let record else { return L10n.Watch.Settings.Complications.never }
        return L10n.Watch.Settings.Complications.lastAttempt(
            record.date.formatted(date: .abbreviated, time: .shortened)
        )
    }

    @MainActor
    private func retry() async {
        isRetrying = true
        _ = await WatchWidgetComplicationSnapshotStore.refresh(configId: config.id)
        record = WatchWidgetComplicationSnapshotStore.records()[config.id]
        isRetrying = false
    }
}

/// Lists the client events recorded on this Watch (sync, database, lifecycle) for on-device debugging.
private struct WatchClientEventsView: View {
    @State private var events: [ClientEvent] = []
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            if events.isEmpty {
                Text(verbatim: L10n.Watch.Settings.ClientEvents.empty)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: DesignSystem.Spaces.one) {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Image(systemSymbol: .trash)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel(Text(verbatim: L10n.Watch.Settings.ClientEvents.clear))
                    .confirmationDialog(
                        Text(verbatim: L10n.ClientEvents.View.ClearConfirm.title),
                        isPresented: $showClearConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(role: .cancel) {} label: { Text(verbatim: L10n.cancelLabel) }
                        Button(role: .destructive) {
                            Current.clientEventStore.clearAllEvents()
                            events = []
                        } label: {
                            Text(verbatim: L10n.yesLabel)
                        }
                    } message: {
                        Text(verbatim: L10n.ClientEvents.View.ClearConfirm.message)
                    }

                    // Shares a zip of the client events plus the on-watch `Current.Log` files, which
                    // are otherwise unreachable — the watch has no other way to hand them over.
                    ShareLink(
                        item: WatchDiagnosticsArchive(),
                        preview: SharePreview(L10n.Watch.Settings.ClientEvents.title)
                    ) {
                        Image(systemSymbol: .squareAndArrowUp)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel(Text(verbatim: L10n.Watch.Settings.ClientEvents.share))
                }
                .buttonStyle(.borderless)

                ForEach(events, id: \.id) { event in
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                        Text(verbatim: event.text)
                            .font(.footnote)
                        Text(
                            verbatim: "\(event.type.rawValue) • "
                                + event.date.formatted(date: .abbreviated, time: .shortened)
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, DesignSystem.Spaces.half)
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.ClientEvents.title))
        .onAppear { events = Current.clientEventStore.getEvents().reversed() }
    }

}
