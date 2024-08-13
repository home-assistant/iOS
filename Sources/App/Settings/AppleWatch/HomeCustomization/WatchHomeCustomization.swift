import Shared
import SwiftUI

struct WatchHomeCustomization: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WatchHomeCustomizationViewModel()

    var body: some View {
        List {
            watchPreview
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .onAppear {
                    viewModel.loadWatchConfig()
                }
            Section {
                Toggle(isOn: $viewModel.watchConfig.showAssist, label: {
                    Text("Show Assist")
                })
            }
            Section("Items") {
                ForEach(viewModel.watchConfig.items, id: \.id) { item in
                    makeListItem(item: item)
                }
                .onMove { indices, newOffset in
                    viewModel.moveItem(from: indices, to: newOffset)
                }
                .onDelete { indexSet in
                    viewModel.deleteItem(at: indexSet)
                }
                Button {
                    viewModel.showAddItem = true
                } label: {
                    Label("Add item", systemImage: "plus")
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(content: {
            Button(action: {
                viewModel.save { success in
                    if success {
                        dismiss()
                    }
                }
            }, label: {
                Text("Save")
            })
        })
        .sheet(isPresented: $viewModel.showAddItem, content: {
            WatchAddItemView { itemToAdd in
                guard let itemToAdd else { return }
                viewModel.addItem(itemToAdd)
            }
        })
    }

    private var watchPreview: some View {
        ZStack {
            watchItemsList
                .offset(x: -10)
            Image(systemName: "applewatch.case.inset.filled")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 260)
                .foregroundStyle(.clear, Color(hue: 0, saturation: 0, brightness: 0.2))
        }
    }

    private var watchItemsList: some View {
        ZStack(alignment: .top) {
            List {
                VStack {}.padding(.top, 40)
                ForEach(viewModel.watchConfig.items, id: \.id) { item in
                    makeWatchItem(item: item)
                }
                if viewModel.watchConfig.items.isEmpty {
                    noItemsWatchView
                }
            }
            .animation(.default, value: viewModel.watchConfig.items)
            .listStyle(.plain)
            .frame(width: 195, height: 235)
            watchStatusBar
        }
    }

    private func makeListItem(item: MagicItem) -> some View {
        let itemInfo = viewModel.magicItemInfo(for: item)
        return makeListItemRow(iconName: itemInfo.iconName, name: itemInfo.name)
    }

    private func makeListItemRow(iconName: String?, name: String) -> some View {
        HStack {
            if let iconName {
                Image(uiImage: MaterialDesignIcons(named: iconName).image(
                    ofSize: .init(width: 18, height: 18),
                    color: .white
                ))
            }
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func makeWatchItem(item: MagicItem) -> some View {
        let itemInfo = viewModel.magicItemInfo(for: item)

        return HStack(spacing: Spaces.one) {
            VStack {
                Image(uiImage: MaterialDesignIcons(named: itemInfo.iconName).image(
                    ofSize: .init(width: 24, height: 24),
                    color: .init(hex: itemInfo.customization?.iconColor)
                ))
                .foregroundColor(Color(uiColor: .init(hex: itemInfo.customization?.iconColor)))
                .padding(Spaces.one)
            }
            .background(Color(uiColor: .init(hex: itemInfo.customization?.iconColor)).opacity(0.3))
            .clipShape(Circle())
            Text(itemInfo.name)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spaces.one)
        .frame(width: 190, height: 55)
        .background(.gray.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, -Spaces.one)
        .listRowSeparator(.hidden)
    }

    private var watchStatusBar: some View {
        ZStack(alignment: .trailing) {
            Text("9:41")
                .font(.system(size: 14).bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top)
            if viewModel.watchConfig.showAssist {
                Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                    ofSize: .init(width: 18, height: 18),
                    color: Asset.Colors.haPrimary.color
                ))
                .padding(Spaces.one)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 25.0))
                .offset(x: -22)
                .padding(.top)
            }
        }
        .animation(.bouncy, value: viewModel.watchConfig.showAssist)
        .frame(width: 210, height: 50)
        .background(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
    }

    private var noItemsWatchView: some View {
        Text(L10n.Watch.Settings.NoItems.Phone.title)
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.footnote)
            .padding(Spaces.one)
            .background(.gray.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationView {
        WatchHomeCustomization()
    }
}
