import SFSafeSymbols
import Shared
import SwiftUI

/// Add flow for the watch configuration, presented as a navigation drill-down:
/// chooser (Entity / Folder) → server (skipped when only one) → entity list → name/icon editor.
/// The phone owns the entity database, so the entity list is fetched from it. Committing performs the
/// mutation, persists, and dismisses the whole sheet via `finish`.
struct WatchConfigAddView: View {
    @ObservedObject var viewModel: WatchHomeViewModel
    /// When set, added items go into this folder instead of the root. Folder creation is only offered
    /// at the root (folders don't nest on the watch).
    let folderId: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            content
                .navigationTitle(Text(verbatim: L10n.Watch.Config.Add.title))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemSymbol: .xmark)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        // Inside a folder the only thing to add is an entity (folders don't nest), so skip the
        // Entity/Folder chooser and go straight to the entity flow.
        if folderId != nil {
            WatchConfigAddEntitySourceView(
                viewModel: viewModel,
                folderId: folderId,
                finish: { dismiss() }
            )
        } else {
            chooser
        }
    }

    private var chooser: some View {
        List {
            NavigationLink {
                WatchConfigAddEntitySourceView(
                    viewModel: viewModel,
                    folderId: folderId,
                    finish: { dismiss() }
                )
            } label: {
                chooserRow(icon: Domain.automation.icon(), title: L10n.Watch.Config.Add.entity)
            }

            NavigationLink {
                WatchConfigItemEditView(
                    mode: .add,
                    placeholderName: L10n.Watch.Config.Edit.namePlaceholder,
                    item: MagicItem(
                        id: UUID().uuidString,
                        serverId: "",
                        type: .folder,
                        displayText: "",
                        items: []
                    ),
                    info: nil
                ) { edited in
                    viewModel.addFolder(named: edited.displayText ?? "", iconName: edited.customization?.icon)
                    viewModel.saveConfig()
                    dismiss()
                }
            } label: {
                chooserRow(icon: .folderIcon, title: L10n.Watch.Config.Add.folder)
            }
        }
    }

    private func chooserRow(icon: MaterialDesignIcons, title: String) -> some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            Image(uiImage: icon.image(ofSize: .init(width: 24, height: 24), color: .white))
                .frame(width: 38, height: 38)
                .modify { view in
                    if #available(watchOS 26.0, *) {
                        view.glassEffect(.clear.tint(Color.white.opacity(0.3)), in: .circle)
                    } else {
                        view
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding([.vertical, .trailing], DesignSystem.Spaces.half)
            Text(verbatim: title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Fetches the addable entities from the phone and either shows the server picker (multiple servers)
/// or jumps straight to the entity list (single server).
private struct WatchConfigAddEntitySourceView: View {
    @ObservedObject var viewModel: WatchHomeViewModel
    let folderId: String?
    let finish: () -> Void

    @State private var available: WatchConfigAvailableItems?
    @State private var loadState: LoadState = .loading

    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private var groups: [WatchConfigAvailableItems.ServerGroup] {
        (available?.servers ?? []).filter { !$0.candidates.isEmpty }
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
            case let .failed(message):
                List {
                    Text(verbatim: message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .loaded:
                if groups.isEmpty {
                    List {
                        Text(verbatim: L10n.Watch.Config.Add.empty)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if groups.count == 1, let group = groups.first {
                    WatchConfigAddEntityListView(
                        group: group,
                        viewModel: viewModel,
                        folderId: folderId,
                        finish: finish
                    )
                } else {
                    List {
                        ForEach(groups, id: \.serverId) { group in
                            NavigationLink {
                                WatchConfigAddEntityListView(
                                    group: group,
                                    viewModel: viewModel,
                                    folderId: folderId,
                                    finish: finish
                                )
                            } label: {
                                Text(verbatim: group.serverName)
                            }
                        }
                    }
                    .navigationTitle(Text(verbatim: L10n.Watch.Config.Assist.selectServer))
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        loadState = .loading
        viewModel.fetchAvailableItems { result in
            switch result {
            case let .success(items):
                available = items
                loadState = .loaded
            case let .failure(error):
                switch error {
                case .notReachable:
                    loadState = .failed(L10n.Watch.Config.Edit.Error.notReachable)
                case .sendFailed, .decodeFailed:
                    loadState = .failed(L10n.Watch.Config.Add.Error.fetchFailed)
                }
            }
        }
    }
}

/// The list of addable entities for a single server. Rows mirror the iOS entity picker: icon, name,
/// and the `Area • Device` context underneath. Tapping pushes the name/icon editor.
private struct WatchConfigAddEntityListView: View {
    let group: WatchConfigAvailableItems.ServerGroup
    @ObservedObject var viewModel: WatchHomeViewModel
    let folderId: String?
    let finish: () -> Void

    @State private var searchTerm = ""
    @State private var selectedDomain: Domain?

    var body: some View {
        List {
            TextField(L10n.Watch.Config.Add.searchPlaceholder, text: $searchTerm)
            if availableDomains.count > 1 {
                domainFilter
                    .listRowBackground(Color.clear)
            }
            ForEach(filteredCandidates, id: \.item.serverUniqueId) { candidate in
                NavigationLink {
                    WatchConfigItemEditView(
                        mode: .add,
                        placeholderName: candidate.info.name,
                        item: candidate.item,
                        info: candidate.info
                    ) { edited in
                        add(edited, info: candidate.info)
                    }
                } label: {
                    WatchConfigItemRow(
                        item: candidate.item,
                        itemInfo: candidate.info,
                        subtitle: candidate.contextSubtitle
                    )
                }
                .watchHomeItemRowStyle(tint: nil)
            }
        }
        .navigationTitle(Text(verbatim: group.serverName))
    }

    private var domainFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spaces.half) {
                WatchDomainFilterPill(title: L10n.Watch.Config.Add.Filter.all, selected: selectedDomain == nil) {
                    selectedDomain = nil
                }
                ForEach(availableDomains, id: \.rawValue) { domain in
                    WatchDomainFilterPill(title: domain.name, selected: selectedDomain == domain) {
                        selectedDomain = selectedDomain == domain ? nil : domain
                    }
                }
            }
        }
    }

    /// The addable domains present in this server's candidates, in the watch's canonical order.
    private var availableDomains: [Domain] {
        let present = Set(group.candidates.compactMap { Domain(entityId: $0.item.id) })
        return [.script, .scene, .automation].filter(present.contains)
    }

    private var filteredCandidates: [WatchConfigAvailableItems.Candidate] {
        var candidates = group.candidates
        if let selectedDomain {
            candidates = candidates.filter { Domain(entityId: $0.item.id) == selectedDomain }
        }
        let term = searchTerm.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return candidates }
        return candidates.filter { $0.item.name(info: $0.info).lowercased().contains(term) }
    }

    private func add(_ item: MagicItem, info: MagicItem.Info) {
        if let folderId {
            viewModel.addItemToFolder(folderId: folderId, item: item, info: info)
        } else {
            viewModel.addItem(item, info: info)
        }
        viewModel.saveConfig()
        finish()
    }
}

/// A small capsule filter chip used above the entity list to narrow the candidates to a single domain.
private struct WatchDomainFilterPill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spaces.one)
                .padding(.vertical, DesignSystem.Spaces.half)
        }
        .buttonStyle(.plain)
        .modify { view in
            if #available(watchOS 26.0, *) {
                view.glassEffect(.regular.tint(selected ? Color.haPrimary : nil).interactive(), in: .capsule)
            } else {
                view
                    .background(selected ? Color.haPrimary : Color.gray.opacity(0.3))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Capsule())
    }
}
