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

    init(selectedEntity: Binding<HAAppEntity?>, domainFilter: Domain?) {
        self.domainFilter = domainFilter
        self._selectedEntity = selectedEntity
    }

    var body: some View {
        Button(action: {
            showList = true
        }, label: {
            if let name = selectedEntity?.name {
                Text(name)
            } else {
                Text(L10n.EntityPicker.placeholder)
            }
        })
        .sheet(isPresented: $showList) {
            NavigationView {
                List {
                    ForEach(Current.servers.all, id: \.identifier) { server in
                        Section(server.info.name) {
                            ForEach(entities.filter({ entity in
                                if searchTerm.count > 2 {
                                    return entity.serverId == server.identifier.rawValue && (
                                        entity.name.lowercased().contains(searchTerm.lowercased()) ||
                                            entity.entityId.lowercased().contains(searchTerm.lowercased())
                                    )
                                } else {
                                    return entity.serverId == server.identifier.rawValue
                                }
                            }), id: \.id) { entity in
                                Button(action: {
                                    selectedEntity = entity
                                    showList = false
                                }, label: {
                                    if let selectedEntity, selectedEntity == entity {
                                        Label(entity.name, systemSymbol: .checkmark)
                                    } else {
                                        Text(entity.name)
                                    }
                                })
                                .tint(.accentColor)
                            }
                        }
                    }
                }
                .searchable(text: $searchTerm)
                .onAppear {
                    fetchEntities()
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
