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
                        scriptsList
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
        makeList(items: viewModel.actions)
    }

    @ViewBuilder
    private var scriptsList: some View {
        ForEach(Array(viewModel.scripts.keys), id: \.identifier) { server in
            Section(server.info.name) {
                makeList(items: viewModel.scripts[server] ?? [])
            }
        }
    }

    @ViewBuilder
    private func makeList(items: [MagicItem]) -> some View {
        ForEach(items, id: \.id) { item in
            switch item.type {
            case let .action(action, _):
                actionRowItem(action, magicItem: item)
            case let .script(script, _):
                scriptRowItem(script)
            }
        }
    }

    @ViewBuilder
    private func actionRowItem(_ action: MagicItem.GenericItem, magicItem: MagicItem) -> some View {
        if visibleForSearch(title: action.title) {
            Button(action: {
                itemToAdd(magicItem)
                dismiss()
            }, label: {
                makeItemRow(title: action.title)
            })
            .tint(.white)
        }
    }

    @ViewBuilder
    private func scriptRowItem(_ script: MagicItem.GenericItem) -> some View {
        if visibleForSearch(title: script.title) {
            NavigationLink {
                Text(script.title)
            } label: {
                makeItemRow(title: script.title, imageSystemName: nil)
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
