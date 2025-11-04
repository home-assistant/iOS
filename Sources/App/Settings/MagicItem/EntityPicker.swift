import SFSafeSymbols
import Shared
import SwiftUI

struct EntityPicker: View {
    @StateObject private var viewModel: EntityPickerViewModel

    /// Returns entityId
    @Binding private var selectedEntity: HAAppEntity?

    init(selectedEntity: Binding<HAAppEntity?>, domainFilter: Domain?) {
        self._selectedEntity = selectedEntity
        self._viewModel = .init(wrappedValue: EntityPickerViewModel(domainFilter: domainFilter))
    }

    var body: some View {
        button
            .sheet(isPresented: $viewModel.showList) {
                screen
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
                        VStack {
                            Group {
                                if let selectedEntity, selectedEntity == entity {
                                    Label(entity.name, systemSymbol: .checkmark)
                                } else {
                                    Text(entity.name)
                                }
                                Text(entity.entityId)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
