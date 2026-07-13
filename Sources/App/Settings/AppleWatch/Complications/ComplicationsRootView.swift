import GRDB
import Shared
import SwiftUI
import UIKit

/// Root of the Complications settings screen. Mirrors the CarPlay / Widgets configuration layout:
/// an Apple-like header, the list of the user's complications with an add button, and the legacy
/// complications tucked behind a navigation link.
struct ComplicationsRootView: View {
    @State private var configs: [WatchComplicationConfig] = []
    /// Context line per config (entity `Area • Device`, or "Template"), computed off the DB in `reload`.
    @State private var subtitles: [String: String] = [:]
    /// Whether any legacy (ClockKit-era) complications exist — the legacy link is hidden otherwise.
    @State private var hasLegacy = false
    @State private var editing: WatchComplicationConfig?
    @State private var showAdd = false
    @State private var isReloading = false
    @State private var reloadAlert: ReloadAlert?

    /// One-off alert describing the result of the manual "Reload" (so it isn't a silent no-op).
    private struct ReloadAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        List {
            header
            yourComplicationsSection

            Section {
                Button {
                    Task { await reload() }
                } label: {
                    HStack {
                        Label(L10n.Watch.Complications.Root.reload, systemSymbol: .arrowClockwise)
                        if isReloading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isReloading)
            } footer: {
                Text(L10n.Watch.Complications.Root.reloadFooter)
            }

            if hasLegacy {
                Section {
                    NavigationLink {
                        ComplicationListView()
                    } label: {
                        Label(
                            title: { Text(L10n.Watch.Complications.Root.legacy) },
                            icon: { Image(systemSymbol: .clockArrowCirclepath) }
                        )
                    }
                } footer: {
                    Text(L10n.Watch.Complications.Root.legacyFooter)
                }
            }

            DebugDatabaseTransferSection(part: .complications) {
                load()
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationView { WatchComplicationBuilderEditView(existing: nil) }
        }
        .sheet(item: $editing) { config in
            NavigationView { WatchComplicationBuilderEditView(existing: config) }
        }
        .alert(item: $reloadAlert) { alert in
            Alert(
                title: Text(verbatim: alert.title),
                message: Text(verbatim: alert.message),
                dismissButton: .default(Text(L10n.okLabel))
            )
        }
        .navigationTitle(Text(verbatim: ""))
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: WatchComplicationConfig.didChangeNotification)) { _ in
            load()
        }
    }

    /// Manual reload: pushes the current complications to the watch and reports the result so the user
    /// isn't left guessing (feedback: silent reload button, and no explanation when the watch is away).
    @MainActor
    private func reload() async {
        isReloading = true
        let outcome = await HomeAssistantAPI.reloadWatchComplications()
        isReloading = false
        switch outcome {
        case .success:
            reloadAlert = ReloadAlert(
                title: L10n.Watch.Complications.Root.reloadSuccessTitle,
                message: L10n.Watch.Complications.Root.reloadSuccessMessage
            )
        case .watchUnavailable:
            reloadAlert = ReloadAlert(
                title: L10n.Watch.Complications.Root.reloadUnavailableTitle,
                message: L10n.Watch.Complications.Root.reloadUnavailableMessage
            )
        case let .failed(message):
            reloadAlert = ReloadAlert(
                title: L10n.Watch.Complications.Root.reloadFailedTitle,
                message: message
            )
        }
    }

    private var header: some View {
        AppleLikeListTopRowHeader(
            image: .watchVariantIcon,
            title: L10n.Watch.Complications.Builder.title,
            subtitle: L10n.Watch.Complications.Root.headerSubtitle
        )
    }

    private var yourComplicationsSection: some View {
        Section(L10n.Watch.Complications.Root.yourComplications) {
            ForEach(configs) { config in
                Button {
                    editing = config
                } label: {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        rowIcon(for: config)
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading) {
                            Text(config.displayName)
                                .foregroundColor(.primary)
                            if let subtitle = subtitles[config.id] {
                                Text(verbatim: subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    // Make the whole row (including empty space) tappable, not just the text.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: delete)

            Button {
                showAdd = true
            } label: {
                Label(L10n.Watch.Complications.Root.new, systemSymbol: .plus)
            }
        }
    }

    /// A plain MDI icon for entity-backed complications, or a gauge glyph as a neutral fallback for
    /// template-backed (or icon-less) ones — not a per-family mock, since a complication works in every size.
    private func rowIcon(for config: WatchComplicationConfig) -> Image {
        let color = config.iconColor.map { UIColor(hex: $0) } ?? AppConstants.tintColor
        let icon: MaterialDesignIcons
        if config.kind == .entity, let iconName = config.iconName {
            // Icon names may be server-side values (e.g. "mdi:home"); normalize before lookup.
            icon = MaterialDesignIcons(serversideValueNamed: iconName)
        } else {
            icon = .gaugeIcon
        }
        return Image(uiImage: icon.image(ofSize: .init(width: 28, height: 28), color: color))
    }

    private func load() {
        hasLegacy = !((try? WatchComplication.all()) ?? []).isEmpty
        let all = (try? WatchComplicationConfig.all()) ?? []
        configs = all
        var map: [String: String] = [:]
        for config in all {
            switch config.kind {
            case .entity:
                guard let entityId = config.entityId else { continue }
                let key = "\(config.serverId)-\(entityId)"
                let entity = try? Current.database().read { db in
                    try HAAppEntity.fetchOne(db, key: key)
                }
                map[config.id] = entity?.contextualSubtitle ?? config.entityDisplayName ?? entityId
            case .customTemplate:
                map[config.id] = L10n.Watch.Complications.Root.template
            }
        }
        subtitles = map
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? configs[index].delete()
        }
        NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
        HomeAssistantAPI.syncWatchContext()
        WatchMirrorPushCoordinator.schedule(reason: .complicationChanged)
        load()
    }
}

#Preview("Complications root") {
    NavigationView { ComplicationsRootView() }
}
