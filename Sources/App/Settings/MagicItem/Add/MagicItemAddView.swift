import Shared
import SwiftUI

struct MagicItemAddView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MagicItemAddViewModel()

    let itemToAdd: (MagicItem?) -> Void

    var body: some View {
        NavigationView {
            VStack {
                Picker(L10n.MagicItem.ItemType.Selection.List.title, selection: $viewModel.selectedItemType) {
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
                scriptsList(scripts: viewModel.scripts[server] ?? [], serverId: server.identifier.rawValue)
            }
        }
    }

    @ViewBuilder
    private func scriptsList(scripts: [HAScript], serverId: String) -> some View {
        ForEach(scripts, id: \.id) { script in
            if visibleForSearch(title: script.name ?? "") {
                NavigationLink {
                    MagicItemCustomizationView(
                        mode: .add,
                        item: .init(id: script.id, serverId: serverId, type: .script)
                    ) { itemToAdd in
                        self.itemToAdd(itemToAdd)
                        dismiss()
                    }
                } label: {
                    makeItemRow(title: script.name ?? "Unknown", imageSystemName: nil)
                }
            }
        }
    }

    @ViewBuilder
    private var scenesPerServerList: some View {
        ForEach(Array(viewModel.scenes.keys), id: \.identifier) { server in
            Section(server.info.name) {
                scenesList(scenes: viewModel.scenes[server] ?? [], serverId: server.identifier.rawValue)
            }
        }
    }

    @ViewBuilder
    private func scenesList(scenes: [HAScene], serverId: String) -> some View {
        ForEach(scenes, id: \.id) { scene in
            if visibleForSearch(title: scene.name ?? "") {
                NavigationLink {
                    MagicItemCustomizationView(mode: .add, item: .init(
                        id: scene.id,
                        serverId: serverId,
                        type: .scene
                    )) { itemToAdd in
                        self.itemToAdd(itemToAdd)
                        dismiss()
                    }
                } label: {
                    makeItemRow(title: scene.name ?? "Unknown", imageSystemName: nil)
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
    MagicItemAddView { _ in
    }
}
