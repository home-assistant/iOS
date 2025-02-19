import SFSafeSymbols
import Shared
import SwiftUI

struct EntityPicker: View {
    /// Returns entityId
    let domainFilter: Domain?
    @State private var showList = false
    @State private var entities: [HAAppEntity] = []
    @Binding private var selectedEntity: HAAppEntity?
    @State private var searchTerm = ""
    @State private var selectedServerId: String?

    init(selectedEntity: Binding<HAAppEntity?>, domainFilter: Domain?) {
        self.domainFilter = domainFilter
        self._selectedEntity = selectedEntity
    }

    var body: some View {
        button
            .sheet(isPresented: $showList) {
                screen
            }
    }

    private var button: some View {
        Button(action: {
            showList = true
        }, label: {
            if let name = selectedEntity?.name {
                Text(name)
            } else {
                Text(L10n.EntityPicker.placeholder)
            }
        })
    }

    private var screen: some View {
        NavigationView {
            List {
                ServersPickerPillList(selectedServerId: $selectedServerId)
                ForEach(entities.filter({ entity in
                    if searchTerm.count > 2 {
                        return entity.serverId == selectedServerId && (
                            entity.name.lowercased().contains(searchTerm.lowercased()) ||
                                entity.entityId.lowercased().contains(searchTerm.lowercased())
                        )
                    } else {
                        return entity.serverId == selectedServerId
                    }
                }), id: \.id) { entity in
                    Button(action: {
                        selectedEntity = entity
                        showList = false
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
            .searchable(text: $searchTerm)
            .onAppear {
                fetchEntities()
                if selectedServerId == nil {
                    selectedServerId = Current.servers.all.first?.identifier.rawValue
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        showList = false
                    }
                }
            }
        }
    }

    private func fetchEntities() {
        do {
            var newEntities = try HAAppEntity.config() ?? []
            if let domainFilter {
                newEntities = newEntities.filter({ entity in
                    entity.domain == domainFilter.rawValue
                })
            }
            entities = newEntities
        } catch {
            Current.Log.error("Failed to fetch entities for entity picker, error: \(error)")
        }
    }
}
