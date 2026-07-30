import SFSafeSymbols
import Shared
import SwiftUI

/// Add flow for the watch configuration, presented as a navigation drill-down:
/// chooser (Entity / Folder) → server (skipped when only one) → entity list → name/icon editor.
/// The phone owns the entity database, so the entity list is fetched from it. Committing performs the
/// mutation, persists, and dismisses the whole sheet via `finish`.
struct WatchConfigAddView: View {
    /// Held without `@ObservedObject` on purpose: the add flow only *calls* the view model (fetch and
    /// mutate) and renders none of its published state, so observing it would rebuild this whole
    /// navigation stack on every unrelated publish — a background sync alone republishes its progress
    /// and status for every chunk it receives.
    let viewModel: WatchHomeViewModel
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

/// Resolves the addable entities from the mirrored database and either shows the server picker
/// (multiple servers) or jumps straight to the area picker (single server). The result is loaded once
/// and kept for the lifetime of the flow — the mirror doesn't change while the sheet is open.
private struct WatchConfigAddEntitySourceView: View {
    let viewModel: WatchHomeViewModel
    let folderId: String?
    let finish: () -> Void

    /// `nil` until the first load finishes, which is what puts the spinner on screen. Everything the
    /// build can't resolve — an unreadable or not-yet-synced mirror included — comes back as no
    /// candidates, which the empty state below covers.
    @State private var available: WatchConfigAvailableItems?
    /// Guards against a second fetch while one is already running (`onAppear` can fire more than once).
    @State private var isFetching = false

    private var groups: [WatchConfigAvailableItems.ServerGroup] {
        (available?.servers ?? []).filter { !$0.candidates.isEmpty }
    }

    var body: some View {
        Group {
            if available == nil {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if groups.isEmpty {
                List {
                    Text(verbatim: L10n.Watch.Config.Add.empty)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if groups.count == 1, let group = groups.first {
                WatchConfigAddAreaListView(
                    group: group,
                    viewModel: viewModel,
                    folderId: folderId,
                    finish: finish
                )
            } else {
                List {
                    ForEach(groups, id: \.serverId) { group in
                        NavigationLink {
                            WatchConfigAddAreaListView(
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
        .onAppear(perform: load)
    }

    private func load() {
        // `onAppear` fires again every time the user navigates back to this screen from a deeper one.
        // Re-fetching there swapped the loaded list back to a spinner and rebuilt every candidate from
        // the database just to show the same rows again, so a finished load is kept.
        guard available == nil, !isFetching else { return }
        isFetching = true
        viewModel.fetchAvailableItems { items in
            available = items
            isFetching = false
        }
    }
}

/// Area layer of the add flow: pick an area — or "All areas" — before the entity list, so long
/// entity lists stay navigable on the small screen.
private struct WatchConfigAddAreaListView: View {
    let group: WatchConfigAvailableItems.ServerGroup
    let viewModel: WatchHomeViewModel
    let folderId: String?
    let finish: () -> Void

    var body: some View {
        List {
            areaRow(title: L10n.EntityPicker.Filter.Area.All.title, areaFilter: nil)
            ForEach(areas, id: \.self) { area in
                areaRow(title: area, areaFilter: area)
            }
        }
        .navigationTitle(Text(verbatim: group.serverName))
    }

    private func areaRow(title: String, areaFilter: String?) -> some View {
        NavigationLink {
            WatchConfigAddEntityListView(
                group: group,
                areaFilter: areaFilter,
                viewModel: viewModel,
                folderId: folderId,
                finish: finish
            )
        } label: {
            Text(verbatim: title)
        }
    }

    private var areas: [String] {
        Array(Set(group.candidates.compactMap(\.areaName))).sorted()
    }
}

/// The list of addable entities for a single server. Rows mirror the iOS entity picker: icon, name,
/// and the `Area • Device` context underneath. Tapping pushes the name/icon editor.
private struct WatchConfigAddEntityListView: View {
    let group: WatchConfigAvailableItems.ServerGroup
    /// When set, only entities in this area are listed ("All areas" passes nil).
    let areaFilter: String?
    let viewModel: WatchHomeViewModel
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
        .navigationTitle(Text(verbatim: areaFilter ?? group.serverName))
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

    private var candidatesInArea: [WatchConfigAvailableItems.Candidate] {
        guard let areaFilter else { return group.candidates }
        return group.candidates.filter { $0.areaName == areaFilter }
    }

    /// The addable domains present in this area's candidates, in the watch's canonical order.
    private var availableDomains: [Domain] {
        let present = Set(candidatesInArea.compactMap { Domain(entityId: $0.item.id) })
        return Domain.watchAddable.filter(present.contains)
    }

    private var filteredCandidates: [WatchConfigAvailableItems.Candidate] {
        var candidates = candidatesInArea
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
