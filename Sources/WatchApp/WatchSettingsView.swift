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
    @State private var showDeleteLocalDataConfirmation = false
    @State private var showDeleteLocalDataResult = false
    @State private var deleteLocalDataSucceeded = false

    var body: some View {
        NavigationView {
            List {
                serversSection
                configurationSection
                layoutSection
                performActionSection
                troubleshootingSection
                deleteLocalDataSection
                restartAppSection
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
                fatalError("User requested app restart from watch settings")
            } label: {
                Label(L10n.Watch.Settings.RestartApp.title, systemSymbol: .arrowClockwise)
            }
        } footer: {
            Text(verbatim: L10n.Watch.Settings.RestartApp.footer)
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
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Troubleshooting.title))
    }
}

/// On-device complication diagnostics: forces a live refresh of every configured complication and
/// shows the per-complication outcome (updated / cached / failed) so connectivity issues are visible
/// without the paired iPhone.
private struct WatchComplicationsDiagnosticsView: View {
    @State private var outcomes: [ComplicationRefreshOutcome] = []
    @State private var isRefreshing = false
    @State private var hasRun = false

    var body: some View {
        List {
            Section {
                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        Label(L10n.Watch.Settings.Complications.refreshing, systemSymbol: .arrowClockwise)
                    } else {
                        Label(L10n.Watch.Settings.Complications.refresh, systemSymbol: .arrowClockwise)
                    }
                }
                .disabled(isRefreshing)
            } footer: {
                Text(verbatim: L10n.Watch.Settings.Complications.footer)
            }

            if hasRun, outcomes.isEmpty {
                Text(verbatim: L10n.Watch.Settings.Complications.empty)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(outcomes) { outcome in
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                        Label {
                            Text(verbatim: outcome.name)
                        } icon: {
                            Image(systemSymbol: icon(for: outcome.status))
                                .foregroundStyle(color(for: outcome.status))
                        }
                        Text(verbatim: statusText(for: outcome))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, DesignSystem.Spaces.half)
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Complications.title))
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        outcomes = await WatchWidgetComplicationSnapshotStore.refresh()
        isRefreshing = false
        hasRun = true
    }

    private func icon(for status: ComplicationRefreshOutcome.Status) -> SFSymbol {
        switch status {
        case .live: return .checkmarkCircleFill
        case .cached: return .clockArrowCirclepath
        case .failed: return .exclamationmarkTriangleFill
        }
    }

    private func color(for status: ComplicationRefreshOutcome.Status) -> Color {
        switch status {
        case .live: return .green
        case .cached: return .orange
        case .failed: return .red
        }
    }

    private func statusText(for outcome: ComplicationRefreshOutcome) -> String {
        switch outcome.status {
        case .live:
            return L10n.Watch.Settings.Complications.Status.live
        case .cached:
            return [L10n.Watch.Settings.Complications.Status.cached, outcome.reason]
                .compactMap { $0 }.joined(separator: " • ")
        case .failed:
            return [L10n.Watch.Settings.Complications.Status.failed, outcome.reason]
                .compactMap { $0 }.joined(separator: " • ")
        }
    }
}

/// Lists the client events recorded on this Watch (sync, database, lifecycle) for on-device debugging.
private struct WatchClientEventsView: View {
    @State private var events: [ClientEvent] = []

    var body: some View {
        List {
            if events.isEmpty {
                Text(verbatim: L10n.Watch.Settings.ClientEvents.empty)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
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

                Section {
                    Button(role: .destructive) {
                        Current.clientEventStore.clearAllEvents()
                        events = []
                    } label: {
                        Label(L10n.Watch.Settings.ClientEvents.clear, systemSymbol: .trash)
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.ClientEvents.title))
        .onAppear { events = Current.clientEventStore.getEvents().reversed() }
    }
}
