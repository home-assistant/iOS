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
    @StateObject private var viewModel: EntityPickerViewModel

    /// Returns entityId
    @Binding private var selectedEntity: HAAppEntity?
    private let mode: Mode

    init(selectedServerId: String? = nil, selectedEntity: Binding<HAAppEntity?>, domainFilter: Domain?, mode: Mode = .button) {
        self._selectedEntity = selectedEntity
        self._viewModel = .init(wrappedValue: EntityPickerViewModel(domainFilter: domainFilter, selectedServerId: selectedServerId))
        self.mode = mode
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
        NavigationView {
            content
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
        }
        .navigationViewStyle(.stack)
    }

    private var content: some View {
        List {
            ServersPickerPillList(selectedServerId: $viewModel.selectedServerId)
            if #unavailable(iOS 26.0) {
                filtersView
            }
            ForEach(
                viewModel.filteredEntitiesByGroup.sorted(by: { $0.key < $1.key }),
                id: \.key
            ) { group, filteredEntities in
                Section(group.uppercased()) {
                    ForEach(filteredEntities, id: \.id) { entity in
                        Button(action: {
                            selectedEntity = entity
                            viewModel.showList = false
                        }, label: {
                            EntityRowView(
                                entity: entity,
                                isSelected: selectedEntity == entity
                            )
                        })
                        .tint(.accentColor)
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchTerm)
        .modify { view in
            if #available(iOS 26.0, *) {
                view.safeAreaBar(edge: .bottom) {
                    filtersView
                        .padding(.horizontal)
                }
            } else {
                view
            }
        }
        .onAppear {
            viewModel.fetchEntities()
            if viewModel.selectedServerId == nil {
                viewModel.selectedServerId = Current.servers.all.first?.identifier.rawValue
            }
        }
    }

    @ViewBuilder
    private var filtersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spaces.one) {
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
