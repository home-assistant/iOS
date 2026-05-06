import Foundation
import SFSafeSymbols
import Shared
import StoreKit
import SwiftUI
import UIKit

struct CarPlayConfigurationView: View {
    private enum AddItemDestination: String, Identifiable {
        case entity
        case assist

        var id: String { rawValue }

        var magicItemType: MagicItemAddType {
            switch self {
            case .entity:
                return .entities
            case .assist:
                return .assistPipelines
            }
        }

        var pickerOption: MagicItemAddView.PickerOption {
            switch self {
            case .entity:
                return .entities
            case .assist:
                return .assistPipelines
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CarPlayConfigurationViewModel

    @State private var isLoaded = false
    @State private var showResetConfirmation = false
    @State private var addItemDestination: AddItemDestination?

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
            advancedSection
            resetView
        }
        .navigationTitle("CarPlay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: windowScene)
                    }
                    dismiss()
                }, label: {
                    Text(L10n.doneLabel)
                })
            }
        })
        .onAppear {
            // Prevent trigger when popping nav controller
            guard !isLoaded else { return }
            viewModel.loadConfig()
            isLoaded = true
        }
        .sheet(item: $addItemDestination, content: { destination in
            MagicItemAddView(
                context: .carPlay,
                initialItemType: destination.magicItemType,
                visiblePickerOptions: [destination.pickerOption]
            ) { itemToAdd in
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
            Picker(L10n.Carplay.Tab.QuickAccess.layout, selection: Binding(
                get: { viewModel.quickAccessLayout },
                set: { viewModel.quickAccessLayout = $0 }
            )) {
                ForEach(CarPlayQuickAccessLayout.allCases, id: \.rawValue) { layout in
                    Text(layout.name).tag(layout)
                }
            }
            ForEach(viewModel.config.quickAccessItems, id: \.id) { item in
                makeListItem(item: item)
            }
            .onMove { indices, newOffset in
                viewModel.moveItem(from: indices, to: newOffset)
            }
            .onDelete { indexSet in
                viewModel.deleteItem(at: indexSet)
            }
            addItemButton
        }
    }

    @ViewBuilder
    private var addItemButton: some View {
        Menu {
            Button {
                addItemDestination = .entity
            } label: {
                Label {
                    Text(L10n.MagicItem.ItemType.Entity.List.title)
                } icon: {
                    Image(systemSymbol: .lightbulb)
                }
            }

            Button {
                addItemDestination = .assist
            } label: {
                Label {
                    Text(isAssistSupported ? L10n.Widgets.Action.Name.assist : "Assist (iOS 26.4+)")
                } icon: {
                    Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                        ofSize: .init(width: 18, height: 18),
                        color: .label
                    ))
                }
            }
            .disabled(!isAssistSupported)
        } label: {
            Label(L10n.Watch.Configuration.AddItem.title, systemSymbol: .plus)
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
        Image(.carplayLogo)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 150)
            .listRowBackground(Color.clear)
    }

    private var tabsSection: some View {
        Section(L10n.CarPlay.Config.Tabs.title) {
            NavigationLink {
                CarPlayTabsSelectionView(viewModel: viewModel)
            } label: {
                Text(viewModel.config.tabs.compactMap(\.name).joined(separator: ", "))
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private var advancedSection: some View {
        NavigationLink {
            CarPlayAdvancedSettingsView()
        } label: {
            Text(L10n.CarPlay.Labels.Settings.Advanced.Section.title)
        }
    }

    private var isAssistSupported: Bool {
        if #available(iOS 26.4, *) {
            return true
        } else {
            return false
        }
    }
}

#Preview {
    CarPlayConfigurationView()
}
