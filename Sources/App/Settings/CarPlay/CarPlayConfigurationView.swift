import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

struct CarPlayConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CarPlayConfigurationViewModel()

    var body: some View {
        NavigationView {
            content
                .navigationTitle("CarPlay")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            dismiss()
                        }, label: {
                            Text(L10n.cancelLabel)
                        })
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            viewModel.save { success in
                                if success {
                                    dismiss()
                                }
                            }
                        }, label: {
                            Text(L10n.Watch.Configuration.Save.title)
                        })
                    }
                })
                .sheet(isPresented: $viewModel.showAddItem, content: {
                    MagicItemAddView { itemToAdd in
                        guard let itemToAdd else { return }
                        viewModel.addItem(itemToAdd)
                    }
                })
        }
        .preferredColorScheme(.dark)
    }

    private var content: some View {
        VStack {
            carPlayPreview
            List {
                tabsSection
                itemsSection
            }
        }
    }

    private var itemsSection: some View {
        Section("Quick Actions") {
            ForEach(viewModel.config.quickActions, id: \.id) { item in
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
                Label(L10n.Watch.Configuration.AddItem.title, systemImage: "plus")
            }
        }
    }

    private func makeListItem(item: MagicItem) -> some View {
        let itemInfo = viewModel.magicItemInfo(for: item)
        return makeListItemRow(item: item, info: itemInfo)
    }

    @ViewBuilder
    private func makeListItemRow(item: MagicItem, info: MagicItem.Info) -> some View {
        if item.type == .action {
            itemRow(item: item, info: info)
        } else {
            NavigationLink {
                MagicItemCustomizationView(mode: .edit, item: item) { updatedMagicItem in
                    viewModel.updateItem(updatedMagicItem)
                }
            } label: {
                itemRow(item: item, info: info)
            }
        }
    }

    private func itemRow(item: MagicItem, info: MagicItem.Info) -> some View {
        HStack {
            Image(uiImage: image(for: item, itemInfo: info, watchPreview: false, color: .white))
            Text(info.name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.gray)
        }
    }

    private func image(
        for item: MagicItem,
        itemInfo: MagicItem.Info,
        watchPreview: Bool,
        color: UIColor? = nil
    ) -> UIImage {
        var icon: MaterialDesignIcons = .abTestingIcon
        switch item.type {
        case .action, .scene:
            icon = MaterialDesignIcons(named: itemInfo.iconName)
        case .script:
            icon = MaterialDesignIcons(serversideValueNamed: itemInfo.iconName, fallback: .scriptTextOutlineIcon)
        }

        return icon.image(
            ofSize: .init(width: watchPreview ? 24 : 18, height: watchPreview ? 24 : 18),
            color: color ?? .init(hex: itemInfo.customization?.iconColor)
        )
    }

    private var carPlayPreview: some View {
        ZStack {
            carPlayBackground
            carPlayContent
        }
        .frame(maxWidth: .infinity)
    }

    private var carPlayContent: some View {
        VStack {
            Text("Hello, World!")
                .font(.largeTitle)
                .foregroundColor(.white)
        }
        .background(.red)
    }

    private var carPlayBackground: some View {
        Image("carplay-config")
            .resizable()
            .frame(maxWidth: .infinity)
            .aspectRatio(contentMode: .fit)
    }

    private var tabsSection: some View {
        Section {
            NavigationLink {
                tabsSelection
            } label: {
                Text("Tabs")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var tabsSelection: some View {
        List {
            Section {
                ForEach(viewModel.config.tabs, id: \.rawValue) { tab in
                    Button {
                        viewModel.updateTab(tab, active: false)
                    } label: {
                        HStack {
                            Text(tab.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: SFSymbol.line3Horizontal.rawValue)
                                .foregroundStyle(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onMove { indices, newOffset in
                    viewModel.moveTab(from: indices, to: newOffset)
                }
                .onDelete { indexSet in
                    viewModel.deleteTab(at: indexSet)
                }
            } header: {
                Text("Active")
            } footer: {
                Text("Swipe left to remove tab")
            }
            if viewModel.config.tabs.count != CarPlayTab.allCases.count {
                Section("Inactive") {
                    ForEach(CarPlayTab.allCases.filter({ tab in
                        !viewModel.config.tabs.contains(tab)
                    }), id: \.rawValue) { tab in
                        Button {
                            viewModel.updateTab(tab, active: true)
                        } label: {
                            HStack {
                                Text(tab.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: SFSymbol.plusCircleFill.rawValue)
                                    .foregroundStyle(.white, .green)
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .animation(.bouncy, value: viewModel.config.tabs)
    }
}

#Preview {
    CarPlayConfigurationView()
}
