import Shared
import SwiftUI

struct MagicItemAddView: View {
    enum Context {
        case watch
        case carPlay
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MagicItemAddViewModel()

    let context: Context
    let itemToAdd: (MagicItem?) -> Void

    var body: some View {
        NavigationView {
            VStack {
                Picker(L10n.MagicItem.ItemType.Selection.List.title, selection: $viewModel.selectedItemType) {
                    if context == .carPlay {
                        Text(L10n.MagicItem.ItemType.Entity.List.title)
                            .tag(MagicItemAddType.entities)
                    }
                    Text(L10n.MagicItem.ItemType.Script.List.title)
                        .tag(MagicItemAddType.scripts)
                    Text(L10n.MagicItem.ItemType.Scene.List.title)
                        .tag(MagicItemAddType.scenes)
                    Text(L10n.MagicItem.ItemType.Action.List.title)
                        .tag(MagicItemAddType.actions)
                }
                .pickerStyle(.segmented)
                .padding()
                List {
                    switch viewModel.selectedItemType {
                    case .actions:
                        actionsList
                    case .scripts:
                        scriptsPerServerList
                    case .scenes:
                        scenesPerServerList
                    case .entities:
                        entitiesPerServerList
                    }
                }
                .searchable(text: $viewModel.searchText)
            }
            .onAppear {
                viewModel.loadContent()
            }
            .toolbar(content: {
                Button(action: {
                    dismiss()
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                })
                .tint(.white)
            })
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var actionsList: some View {
        actionsDeprecationDisclaimer
        ForEach(viewModel.actions, id: \.ID) { action in
            if visibleForSearch(title: action.Text) {
                Button(action: {
                    itemToAdd(.init(id: action.ID, serverId: action.serverIdentifier, type: .action))
                    dismiss()
                }, label: {
                    makeItemRow(title: action.Text)
                })
                .tint(.white)
            }
        }
    }

    private var actionsDeprecationDisclaimer: some View {
        Section {
            Button {
                viewModel.selectedItemType = .scripts
            } label: {
                Text(L10n.MagicItem.ItemType.Action.List.Warning.title)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var scriptsPerServerList: some View {
        ForEach(Array(viewModel.scripts.keys), id: \.identifier) { server in
            Section(server.info.name) {
                list(entities: viewModel.scripts[server] ?? [], serverId: server.identifier.rawValue, type: .script)
            }
        }
    }

    @ViewBuilder
    private var scenesPerServerList: some View {
        ForEach(Array(viewModel.scenes.keys), id: \.identifier) { server in
            Section(server.info.name) {
                list(entities: viewModel.scenes[server] ?? [], serverId: server.identifier.rawValue, type: .scene)
            }
        }
    }

    @ViewBuilder
    private var entitiesPerServerList: some View {
        ForEach(Array(viewModel.entities.keys), id: \.identifier) { server in
            Section(server.info.name) {
                list(entities: viewModel.entities[server] ?? [], serverId: server.identifier.rawValue, type: .entity)
            }
        }
    }

    @ViewBuilder
    private func list(entities: [HAAppEntity], serverId: String, type: MagicItem.ItemType) -> some View {
        ForEach(entities, id: \.id) { entity in
            if visibleForSearch(title: entity.name) {
                NavigationLink {
                    MagicItemCustomizationView(mode: .add, item: .init(
                        id: entity.entityId,
                        serverId: serverId,
                        type: type
                    )) { itemToAdd in
                        self.itemToAdd(itemToAdd)
                        dismiss()
                    }
                } label: {
                    makeItemRow(title: entity.name, imageSystemName: nil)
                }
            }
        }
    }

    private func makeItemRow(
        title: String,
        imageSystemName: String? = "plus.circle.fill",
        imageColor: Color? = .green
    ) -> some View {
        HStack {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let imageSystemName, let imageColor {
                Image(systemName: imageSystemName)
                    .foregroundStyle(.white, imageColor)
                    .font(.title3)
            }
        }
    }

    private func visibleForSearch(title: String) -> Bool {
        viewModel.searchText.count < 3 || title.lowercased().contains(viewModel.searchText.lowercased())
    }
}

#Preview {
    MagicItemAddView(context: .carPlay) { _ in
    }
}
