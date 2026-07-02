import Shared
import SwiftUI

struct MacToolbarSettingsView: View {
    @StateObject private var viewModel = MacToolbarSettingsViewModel()

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .dockWindowIcon,
                title: L10n.Settings.MacToolbar.title,
                subtitle: L10n.Settings.MacToolbar.headerSubtitle
            )

            Section(header: Text(L10n.Settings.MacToolbar.HowToAdd.header)) {
                Label {
                    Text(L10n.Settings.MacToolbar.HowToAdd.body)
                        .font(.callout)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemSymbol: .infoCircle)
                        .foregroundColor(.haPrimary)
                }
            }

            Section(header: Text(L10n.Settings.MacToolbar.EntitiesSection.header)) {
                if viewModel.items.isEmpty {
                    Text(L10n.Settings.MacToolbar.emptyState)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.items, id: \.self) { item in
                        MacToolbarEntityRow(item: item) {
                            viewModel.remove(item)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.MacToolbar.title)
        .onAppear {
            viewModel.load()
        }
    }
}

private struct MacToolbarEntityRow: View {
    let item: MagicItem
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    private var icon: MaterialDesignIcons {
        MaterialDesignIcons(named: item.customization?.icon ?? "", fallback: .dotsGridIcon)
    }

    private var serverName: String? {
        guard Current.servers.all.count > 1 else { return nil }
        return Current.servers.server(forServerIdentifier: item.serverId)?.info.name
    }

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(item.displayText ?? item.id)
                    if let serverName {
                        Text(serverName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } icon: {
                MaterialDesignIconsImage(icon: icon, size: 24)
            }
            Spacer()
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Image(systemSymbol: .trash)
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.Settings.MacToolbar.removeAccessibilityLabel(item.displayText ?? item.id))
            .confirmationDialog(
                L10n.Settings.MacToolbar.RemoveConfirmation.title(item.displayText ?? item.id),
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(L10n.Settings.MacToolbar.remove, role: .destructive) {
                    onDelete()
                }
                Button(L10n.cancelLabel, role: .cancel) {}
            }
        }
    }
}

@MainActor
final class MacToolbarSettingsViewModel: ObservableObject {
    @Published private(set) var items: [MagicItem] = []

    func load() {
        do {
            items = try MacToolbarConfig.config()?.items ?? []
        } catch {
            Current.Log.error("Failed to load Mac toolbar config: \(error.localizedDescription)")
            items = []
        }
    }

    func remove(_ item: MagicItem) {
        persist(items: items.filter { $0 != item })
    }

    private func persist(items newItems: [MagicItem]) {
        do {
            var config = try MacToolbarConfig.config() ?? MacToolbarConfig()
            config.items = newItems
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            items = newItems
            NotificationCenter.default.post(name: .macToolbarConfigDidChange, object: nil)
        } catch {
            Current.Log.error("Failed to update Mac toolbar config: \(error.localizedDescription)")
        }
    }
}
