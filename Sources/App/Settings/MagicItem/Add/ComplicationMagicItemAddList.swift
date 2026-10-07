import SFSafeSymbols
import Shared
import SwiftUI

/// Picker for putting an already-configured watch complication in the watch's list of items.
///
/// Only lists complications that already exist — this screen never creates one. Rectangular is the
/// only family offered; see `WatchComplicationConfig.watchListAddable()` for why.
struct ComplicationMagicItemAddList: View {
    @State private var complications: [WatchComplicationConfig] = []
    @State private var searchTerm = ""

    let itemToAdd: (MagicItem) -> Void

    var body: some View {
        List {
            if complications.isEmpty {
                Section {
                    Text(L10n.MagicItem.ItemType.Complication.List.empty)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(serverIds, id: \.self) { serverId in
                Section(serverName(serverId: serverId)) {
                    ForEach(filteredComplications(serverId: serverId), id: \.id) { config in
                        Button {
                            itemToAdd(.init(complication: config))
                        } label: {
                            row(for: config)
                        }
                        .tint(Color(uiColor: .label))
                    }
                }
            }
        }
        .searchable(text: $searchTerm)
        .onAppear(perform: load)
    }

    private func row(for config: WatchComplicationConfig) -> some View {
        HStack {
            Image(uiImage: icon(for: config))
            VStack(alignment: .leading, spacing: 2) {
                Text(config.displayName)
                if let subtitle = config.entityDisplayName ?? config.entityId {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemSymbol: .plusCircleFill)
                .foregroundStyle(Color.accentColor)
        }
    }

    private func icon(for config: WatchComplicationConfig) -> UIImage {
        let icon = config.iconName.map { MaterialDesignIcons(serversideValueNamed: $0) } ?? .watchIcon
        return icon.image(
            ofSize: .init(width: 18, height: 18),
            color: config.iconColor.map { UIColor(hex: $0) } ?? .haPrimary
        )
    }

    /// Servers that actually have addable complications, in the app's server order.
    private var serverIds: [String] {
        let present = Set(complications.map(\.serverId))
        return Current.servers.all.map(\.identifier.rawValue).filter(present.contains)
    }

    private func filteredComplications(serverId: String) -> [WatchComplicationConfig] {
        let forServer = complications.filter { $0.serverId == serverId }
        let term = searchTerm.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return forServer }
        return forServer.filter { $0.displayName.lowercased().contains(term) }
    }

    private func serverName(serverId: String) -> String {
        Current.servers.all.first(where: { $0.identifier.rawValue == serverId })?.info.name ?? serverId
    }

    private func load() {
        do {
            complications = try WatchComplicationConfig.watchListAddable()
        } catch {
            Current.Log.error("Failed to fetch watch complications: \(error.localizedDescription)")
            complications = []
        }
    }
}

#Preview {
    NavigationStack {
        ComplicationMagicItemAddList { _ in }
    }
}
