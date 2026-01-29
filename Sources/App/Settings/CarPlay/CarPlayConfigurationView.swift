import Foundation
import SFSafeSymbols
import Shared
import StoreKit
import SwiftUI

struct CarPlayConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CarPlayConfigurationViewModel

    @State private var isLoaded = false
    @State private var showResetConfirmation = false

    private let needsNavigationController: Bool

    init(needsNavigationController: Bool = true, viewModel: CarPlayConfigurationViewModel? = nil) {
        self.needsNavigationController = needsNavigationController
        self._viewModel = .init(wrappedValue: viewModel ?? CarPlayConfigurationViewModel())
    }

    var body: some View {
        if needsNavigationController {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    content
                }
            } else {
                NavigationView {
                    content
                }
            }
        } else {
            content
        }
    }

    private var content: some View {
        List {
            carPlayLogo
            tabsSection
            itemsSection
            resetView
        }
        .navigationTitle("CarPlay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    let success = viewModel.save()
                    if success {
                        SKStoreReviewController.requestReview()
                        dismiss()
                    }
                }, label: {
                    Text(verbatim: L10n.Watch.Configuration.Save.title)
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
                Text(verbatim: L10n.okLabel)
            })
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
                Label(L10n.Watch.Configuration.AddItem.title, systemSymbol: .plus)
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
                MagicItemCustomizationView(mode: .edit, context: .carPlay, item: item) { updatedMagicItem in
                    viewModel.updateItem(updatedMagicItem)
                }
            } label: {
                itemRow(item: item, info: info)
            }
        }
    }

    private func itemRow(item: MagicItem, info: MagicItem.Info) -> some View {
        HStack {
            Image(uiImage: image(for: item, itemInfo: info, watchPreview: false, color: .accent))
            Text(item.name(info: info))
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemSymbol: .line3Horizontal)
                .foregroundStyle(.gray)
        }
    }

    private func image(
        for item: MagicItem,
        itemInfo: MagicItem.Info,
        watchPreview: Bool,
        color: UIColor? = nil
    ) -> UIImage {
        let icon: MaterialDesignIcons = item.icon(info: itemInfo)

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
                            Image(systemSymbol: .line3Horizontal)
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
                Text(L10n.CarPlay.Tabs.Active.title)
            } footer: {
                Text(L10n.CarPlay.Tabs.Active.DeleteAction.title)
            }
            if viewModel.config.tabs.count != CarPlayTab.allCases.count {
                Section(L10n.CarPlay.Tabs.Inactive.title) {
                    ForEach(CarPlayTab.allCases.filter({ tab in
                        !viewModel.config.tabs.contains(tab)
                    }), id: \.rawValue) { tab in
                        Button {
                            viewModel.updateTab(tab, active: true)
                        } label: {
                            HStack {
                                Text(tab.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemSymbol: .plusCircleFill)
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
