import SFSafeSymbols
import Shared
import SwiftUI

struct EntityPicker: View {
    enum Mode {
        case button
        case list
        case inline
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    @StateObject private var viewModel: EntityPickerViewModel

    /// Returns entityId
    @Binding private var selectedEntity: HAAppEntity?
    private let mode: Mode

    /// When `true` the picker lets the user select several entities and only reports them once the
    /// user confirms. A single selection still flows through `selectedEntity` so callers can keep
    /// their existing single-selection behaviour (e.g. showing a customization screen).
    private let allowMultipleSelection: Bool
    /// Called when the user confirms a selection of two or more entities. Single selections are
    /// reported through `selectedEntity` instead.
    private let onMultipleSelectionConfirmed: (([HAAppEntity]) -> Void)?

    @State private var selectedEntities: [HAAppEntity] = []

    init(
        selectedServerId: String? = nil,
        selectedEntity: Binding<HAAppEntity?>,
        domainFilter: [Domain]?,
        mode: Mode = .button,
        initialSearchTerm: String? = nil,
        allowMultipleSelection: Bool = false,
        onMultipleSelectionConfirmed: (([HAAppEntity]) -> Void)? = nil
    ) {
        self._selectedEntity = selectedEntity
        self._viewModel = .init(wrappedValue: EntityPickerViewModel(
            domainFilter: domainFilter,
            selectedServerId: selectedServerId,
            initialSearchTerm: initialSearchTerm
        ))
        self.mode = mode
        self.allowMultipleSelection = allowMultipleSelection
        self.onMultipleSelectionConfirmed = onMultipleSelectionConfirmed
    }

    var body: some View {
        Group {
            switch mode {
            case .button:
                button
                    .sheet(isPresented: $viewModel.showList) {
                        fullscreen
                    }
            case .list:
                fullscreen
            case .inline:
                content
            }
        }
    }

    private var button: some View {
        Button(action: {
            viewModel.showList = true
        }, label: {
            if let name = selectedEntity?.name {
                Text(name)
            } else {
                Text(verbatim: L10n.EntityPicker.placeholder)
            }
        })
    }

    private var fullscreen: some View {
        content
        #if targetEnvironment(macCatalyst)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CloseButton {
                    if mode == .button {
                        viewModel.showList = false
                    } else {
                        dismiss()
                    }
                }
            }
        }
        #endif
        .navigationViewStyle(.stack)
        #if !targetEnvironment(macCatalyst)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        #endif
    }

    private var content: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, DesignSystem.Spaces.two)
                .padding(.vertical, DesignSystem.Spaces.one)
            list
        }
        .onAppear {
            viewModel.fetchEntities()
            if viewModel.selectedServerId == nil {
                viewModel.selectedServerId = Current.servers.all.first?.identifier.rawValue
            }
            isSearchFocused = true
        }
    }

    private var list: some View {
        List {
            refreshProgressRow
            filtersView
            ForEach(viewModel.filteredGroups) { group in
                Section {
                    ForEach(group.entities, id: \.id) { entity in
                        Button(action: {
                            if allowMultipleSelection {
                                toggleSelection(entity)
                            } else {
                                selectedEntity = entity
                                viewModel.showList = false
                            }
                        }, label: {
                            EntityRowView(
                                entity: entity,
                                isSelected: isSelected(entity)
                            )
                        })
                        .tint(.accentColor)
                    }
                } header: {
                    sectionHeader(for: group)
                }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            multipleSelectionConfirmButton
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isRefreshing)
        #if targetEnvironment(macCatalyst)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    reloadToolbarButton
                }
            }
        #else
            .refreshable {
                await viewModel.refresh()
            }
        #endif
    }

    private var searchField: some View {
        capsuleFieldBackground(
            TextField(L10n.EntityPicker.Search.placeholder, text: $viewModel.searchTerm)
                .focused($isSearchFocused)
                .textFieldStyle(.plain)
                .padding()
        )
    }

    @ViewBuilder
    private func capsuleFieldBackground(_ content: some View) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(Capsule())
        } else {
            content
                .background(.tileBackground)
                .clipShape(.capsule)
        }
    }

    @ViewBuilder
    private var refreshProgressRow: some View {
        if viewModel.isRefreshing {
            Section {
                HStack(spacing: DesignSystem.Spaces.two) {
                    ProgressView()
                    Text(viewModel.refreshStatusText ?? L10n.EntityPicker.Refresh.updating)
                        .font(DesignSystem.Font.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .transition(.opacity)
            }
        }
    }

    #if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var reloadToolbarButton: some View {
        if viewModel.isRefreshing {
            ProgressView()
                .controlSize(.small)
                .transition(.opacity)
        } else {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemSymbol: .arrowClockwise)
            }
            .accessibilityLabel(L10n.EntityPicker.reload)
            .transition(.opacity)
        }
    }
    #endif

    @ViewBuilder
    private func sectionHeader(for group: EntityPickerGroup) -> some View {
        HStack {
            Text(group.title.uppercased())
            if allowMultipleSelection {
                Spacer()
                let allSelected = allEntitiesSelected(in: group)
                Button(allSelected ? L10n.EntityPicker.removeAll : L10n.EntityPicker.selectAll) {
                    if allSelected {
                        removeAll(in: group)
                    } else {
                        selectAll(in: group)
                    }
                }
                .textCase(nil)
                .font(DesignSystem.Font.footnote)
                .tint(.haPrimary)
            }
        }
    }

    @ViewBuilder
    private var multipleSelectionConfirmButton: some View {
        if allowMultipleSelection, !selectedEntities.isEmpty {
            Button(action: confirmMultipleSelection) {
                Text(L10n.EntityPicker.addSelected(selectedEntities.count))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.haPrimary)
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func isSelected(_ entity: HAAppEntity) -> Bool {
        if allowMultipleSelection {
            selectedEntities.contains(where: { $0.id == entity.id })
        } else {
            selectedEntity == entity
        }
    }

    private func toggleSelection(_ entity: HAAppEntity) {
        if let index = selectedEntities.firstIndex(where: { $0.id == entity.id }) {
            selectedEntities.remove(at: index)
        } else {
            selectedEntities.append(entity)
        }
    }

    private func allEntitiesSelected(in group: EntityPickerGroup) -> Bool {
        let selectedIds = Set(selectedEntities.map(\.id))
        return !group.entities.isEmpty && group.entities.allSatisfy { selectedIds.contains($0.id) }
    }

    private func selectAll(in group: EntityPickerGroup) {
        var existingIds = Set(selectedEntities.map(\.id))
        for entity in group.entities where existingIds.insert(entity.id).inserted {
            selectedEntities.append(entity)
        }
    }

    private func removeAll(in group: EntityPickerGroup) {
        let groupIds = Set(group.entities.map(\.id))
        selectedEntities.removeAll { groupIds.contains($0.id) }
    }

    private func confirmMultipleSelection() {
        // A single entity keeps the normal flow (e.g. customization) via the selectedEntity binding;
        // two or more are reported directly so callers can add them with their default configuration.
        if selectedEntities.count == 1 {
            selectedEntity = selectedEntities.first
        } else {
            onMultipleSelectionConfirmed?(selectedEntities)
        }
        // Close the sheet when the picker presents its own (`.button` mode).
        viewModel.showList = false
    }

    @ViewBuilder
    private var filtersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spaces.one) {
                if viewModel.hasActiveFilters {
                    resetFiltersButton
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                serverPicker
                areaPicker
                domainPicker
                groupByPicker
            }
            .padding(.horizontal, DesignSystem.Spaces.one)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .modify { view in
            if #available(iOS 17.0, *) {
                view.scrollClipDisabled()
            } else {
                view
            }
        }
    }

    private var resetFiltersButton: some View {
        Button {
            viewModel.resetFilters()
        } label: {
            Image(systemSymbol: .arrowUturnLeftCircleFill)
        }
        .tint(.haPrimary)
        .modify { view in
            if #available(iOS 26.0, *) {
                view.buttonStyle(.bordered)
            } else {
                view
            }
        }
    }

    @ViewBuilder
    private var serverPicker: some View {
        let servers = Current.servers.all
        if servers.count > 1 {
            EntityFilterPickerView(
                title: L10n.EntityPicker.Filter.Server.title,
                icon: .serverRack,
                pickerItems: servers.sorted(by: { $0.info.sortOrder < $1.info.sortOrder }).map {
                    EntityFilterPickerView.PickerItem(id: $0.identifier.rawValue, title: $0.info.name)
                },
                selectedItemId: $viewModel.selectedServerId
            )
        }
    }

    // Shown whenever there is more than one domain to choose from, including contexts that preset a
    // list of allowed domains (e.g. the watch, which supports every actionable domain).
    @ViewBuilder
    private var domainPicker: some View {
        if viewModel.selectableDomains.count > 1 {
            EntityFilterPickerView(
                title: L10n.EntityPicker.Filter.Domain.title,
                icon: .tag,
                pickerItems: [EntityFilterPickerView.PickerItem(
                    id: "",
                    title: L10n.EntityPicker.Filter.Domain.All.title
                )] +
                    viewModel.selectableDomains.map { key in
                        // Prefer the domain's localized name (backed by CoreStrings); fall back to the raw key.
                        EntityFilterPickerView.PickerItem(id: key, title: Domain(rawValue: key)?.name ?? key)
                    }
                    .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending },
                selectedItemId: Binding(
                    get: { viewModel.selectedDomainFilter ?? "" },
                    set: { viewModel.selectedDomainFilter = ($0?.isEmpty ?? true) ? nil : $0 }
                )
            )
        }
    }

    @ViewBuilder
    private var areaPicker: some View {
        if !viewModel.areaData.isEmpty {
            EntityFilterPickerView(
                title: L10n.EntityPicker.Filter.Area.title,
                icon: .houseFill,
                pickerItems: [EntityFilterPickerView.PickerItem(
                    id: "",
                    title: L10n.EntityPicker.Filter.Area.All.title
                )] +
                    viewModel.areaData.sorted(by: { $0.name < $1.name }).map {
                        EntityFilterPickerView.PickerItem(id: $0.areaId, title: $0.name)
                    },
                selectedItemId: Binding(
                    get: { viewModel.selectedAreaFilter ?? "" },
                    set: { viewModel.selectedAreaFilter = ($0?.isEmpty ?? true) ? nil : $0 }
                )
            )
        }
    }

    // Grouping by domain only says something when several domains are listed.
    @ViewBuilder
    private var groupByPicker: some View {
        if viewModel.selectableDomains.count > 1 {
            EntityFilterPickerView(
                title: L10n.EntityPicker.Filter.GroupBy.title,
                icon: .listBulletRectangle,
                pickerItems: EntityGrouping.allCases.map {
                    EntityFilterPickerView.PickerItem(id: $0.rawValue, title: $0.displayName)
                },
                selectedItemId: Binding(
                    get: { viewModel.selectedGrouping.rawValue },
                    set: {
                        if let grouping = EntityGrouping(rawValue: $0 ?? "") { viewModel.selectedGrouping = grouping }
                    }
                )
            )
        }
    }
}

#Preview {
    EntityPicker(selectedServerId: nil, selectedEntity: .constant(nil), domainFilter: nil, mode: .list)
}
