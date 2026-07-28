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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var content: some View {
        List {
            Section {
                TextField(L10n.EntityPicker.Search.placeholder, text: $viewModel.searchTerm)
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .padding()
                    .modify { view in
                        if #available(iOS 26.0, *) {
                            view
                                .glassEffect(.regular.interactive(), in: .capsule)
                                .contentShape(Capsule())

                        } else {
                            view
                                .background(.tileBackground)
                                .clipShape(.capsule)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            filtersView
            ForEach(viewModel.filteredGroups) { group in
                Section(group.title.uppercased()) {
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
                }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            multipleSelectionConfirmButton
        }
        .onAppear {
            viewModel.fetchEntities()
            if viewModel.selectedServerId == nil {
                viewModel.selectedServerId = Current.servers.all.first?.identifier.rawValue
            }
            isSearchFocused = true
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
                groupByPicker
                domainPicker
                areaPicker
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
                pickerItems: servers.sorted(by: { $0.info.sortOrder < $1.info.sortOrder }).map {
                    EntityFilterPickerView.PickerItem(id: $0.identifier.rawValue, title: $0.info.name)
                },
                selectedItemId: $viewModel.selectedServerId
            )
        }
    }

    @ViewBuilder
    private var domainPicker: some View {
        if viewModel.domainFilter == nil {
            EntityFilterPickerView(
                title: L10n.EntityPicker.Filter.Domain.title,
                pickerItems: [EntityFilterPickerView.PickerItem(
                    id: "",
                    title: L10n.EntityPicker.Filter.Domain.All.title
                )] +
                    viewModel.entitiesByDomain.keys.sorted().map {
                        EntityFilterPickerView.PickerItem(id: $0, title: $0.uppercased())
                    },
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

    @ViewBuilder
    private var groupByPicker: some View {
        if viewModel.domainFilter == nil {
            EntityFilterPickerView(
                title: L10n.EntityPicker.Filter.GroupBy.title,
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
