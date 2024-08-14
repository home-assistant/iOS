import Shared
import SwiftUI

struct WatchAddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WatchAddItemViewModel()

    let itemToAdd: (MagicItem?) -> Void

    var body: some View {
        NavigationView {
            VStack {
                Picker("Item type", selection: $viewModel.selectedItemType) {
                    Text("Scripts")
                        .tag(WatchAddItemType.scripts)
                    Text("Actions (Legacy)")
                        .tag(WatchAddItemType.actions)
                }
                .pickerStyle(.segmented)
                .padding()
                List {
                    switch viewModel.selectedItemType {
                    case .actions:
                        actionsList
                    case .scripts:
                        scriptsPerServerList
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

    private var actionsList: some View {
        ForEach(viewModel.actions, id: \.ID) { action in
            if visibleForSearch(title: action.Text) {
                Button(action: {
                    itemToAdd(.init(id: action.ID, type: .action))
                    dismiss()
                }, label: {
                    makeItemRow(title: action.Text)
                })
                .tint(.white)
            }
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
                    MagicItemEditView(item: .init(id: script.id, serverId: serverId, type: .script)) { itemToAdd in
                        self.itemToAdd(itemToAdd)
                        dismiss()
                    }
                } label: {
                    makeItemRow(title: script.name ?? "Unknown", imageSystemName: nil)
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
    WatchAddItemView { _ in
    }
}
