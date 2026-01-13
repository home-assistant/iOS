import SFSafeSymbols
import Shared
import SwiftUI

struct EntityPicker: View {
    enum Mode {
        case button
        case list
    }

    @StateObject private var viewModel: EntityPickerViewModel

    /// Returns entityId
    @Binding private var selectedEntity: HAAppEntity?
    private let mode: Mode

    init(selectedEntity: Binding<HAAppEntity?>, domainFilter: Domain?, mode: Mode = .button) {
        self._selectedEntity = selectedEntity
        self._viewModel = .init(wrappedValue: EntityPickerViewModel(domainFilter: domainFilter))
        self.mode = mode
    }

    var body: some View {
        Group {
            switch mode {
            case .button:
                button
                    .sheet(isPresented: $viewModel.showList) {
                        screen
                    }

            case .list:
                screen
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

    private var screen: some View {
        NavigationView {
            List {
                ServersPickerPillList(selectedServerId: $viewModel.selectedServerId)
                ForEach(viewModel.entities.filter({ entity in
                    if viewModel.searchTerm.count > 2 {
                        return entity.serverId == viewModel.selectedServerId && (
                            entity.name.lowercased().contains(viewModel.searchTerm.lowercased()) ||
                                entity.entityId.lowercased().contains(viewModel.searchTerm.lowercased())
                        )
                    } else {
                        return entity.serverId == viewModel.selectedServerId
                    }
                }), id: \.id) { entity in
                    Button(action: {
                        selectedEntity = entity
                        viewModel.showList = false
                    }, label: {
                        MagicItemRow(
                            entity: entity,
                            isSelected: selectedEntity == entity
                        )
                    })
                    .tint(.accentColor)
                }
            }
            .searchable(text: $viewModel.searchTerm)
            .onAppear {
                viewModel.fetchEntities()
                if viewModel.selectedServerId == nil {
                    viewModel.selectedServerId = Current.servers.all.first?.identifier.rawValue
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        viewModel.showList = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
