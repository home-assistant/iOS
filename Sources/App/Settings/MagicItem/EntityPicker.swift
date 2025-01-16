import SFSafeSymbols
import Shared
import SwiftUI

struct EntityPicker: View {
    /// Returns entityId
    let action: (HAAppEntity) -> Void
    let domainFilter: Domain?

    init(domainFilter: Domain?, action: @escaping (HAAppEntity) -> Void) {
        self.action = action
        self.domainFilter = domainFilter
    }

    @State private var showList = false
    @State private var entities: [HAAppEntity] = []
    @State private var selectedEntity: HAAppEntity?
    @State private var searchTerm = ""

    var body: some View {
        Button(action: {
            showList = true
        }, label: {
            Text(selectedEntity?.name ?? L10n.EntityPicker.placeholder)
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
                                    action(entity)
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
