import Foundation
import SFSafeSymbols
import Shared
import StoreKit
import SwiftUI

struct CarPlayConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CarPlayConfigurationViewModel()

    @State private var isLoaded = false
    @State private var showResetConfirmation = false

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
                                    // When iOS 15 support is dropped we can start using `@Environment(\.requestReview)
                                    // private var requestReview`
                                    SKStoreReviewController.requestReview()
                                    dismiss()
                                }
                            }
                        }, label: {
                            Text(L10n.Watch.Configuration.Save.title)
                        })
                    }
                })
                .onAppear {
                    // Prevent trigger when popping nav controller
                    guard !isLoaded else { return }
                    viewModel.loadConfig()
                    isLoaded = true
                }
                .sheet(isPresented: $viewModel.showAddItem, content: {
                    MagicItemAddView(context: .carPlay) { itemToAdd in
                        guard let itemToAdd else { return }
                        viewModel.addItem(itemToAdd)
                    }
                })
                .alert(viewModel.errorMessage ?? L10n.errorLabel, isPresented: $viewModel.showError) {
                    Button(action: {}, label: {
                        Text(L10n.okLabel)
                    })
                }
        }
        .preferredColorScheme(.dark)
        .navigationViewStyle(.stack)
    }

    private var content: some View {
        List {
            carPlayLogo
            tabsSection
            itemsSection
            resetView
        }
    }

    private var itemsSection: some View {
        Section(L10n.CarPlay.Navigation.Tab.quickAccess) {
            ForEach(viewModel.config.quickAccessItems, id: \.id) { item in
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
        let itemInfo = viewModel.magicItemInfo(for: item) ?? .init(
            id: item.id,
            name: item.id,
            iconName: "",
            customization: nil
        )
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
        var icon: MaterialDesignIcons = .dotsGridIcon
        switch item.type {
        case .action, .scene:
            icon = MaterialDesignIcons(named: itemInfo.iconName)
        case .script, .entity:
            icon = MaterialDesignIcons(serversideValueNamed: itemInfo.iconName, fallback: .dotsGridIcon)
        }

        return icon.image(
            ofSize: .init(width: watchPreview ? 24 : 18, height: watchPreview ? 24 : 18),
            color: color ?? .init(hex: itemInfo.customization?.iconColor)
        )
    }

    private var carPlayLogo: some View {
        Image("carplay-logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 150)
            .padding()
            .listRowBackground(Color.clear)
    }

    private var tabsSection: some View {
        Section(L10n.CarPlay.Config.Tabs.title) {
            NavigationLink {
                tabsSelection
            } label: {
                Text(viewModel.config.tabs.compactMap(\.name).joined(separator: ", "))
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

    private var resetView: some View {
        Button(L10n.CarPlay.Debug.DeleteDb.Reset.title, role: .destructive) {
            showResetConfirmation = true
        }
        .confirmationDialog(
            L10n.CarPlay.Debug.DeleteDb.Alert.title,
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.yesLabel, role: .destructive) {
                viewModel.deleteConfiguration { success in
                    if success {
                        dismiss()
                    }
                }
            }
            Button(L10n.noLabel, role: .cancel) {}
        }
    }
}

#Preview {
    CarPlayConfigurationView()
}
