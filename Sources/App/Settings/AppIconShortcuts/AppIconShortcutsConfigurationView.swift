import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

struct AppIconShortcutsConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AppIconShortcutsConfigurationViewModel()

    @State private var isLoaded = false
    @State private var showResetConfirmation = false

    var body: some View {
        List {
            header
            itemsSection
            resetView
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !isLoaded else { return }
            viewModel.loadConfig()
            isLoaded = true
        }
        .sheet(isPresented: $viewModel.showAddItem) {
            MagicItemAddView(context: .appIconShortcut) { itemToAdd in
                guard let itemToAdd else { return }
                viewModel.addItem(itemToAdd)
            }
        }
        .alert(viewModel.errorMessage ?? L10n.errorLabel, isPresented: $viewModel.showError) {
            Button(action: {}, label: {
                Text(verbatim: L10n.okLabel)
            })
        }
    }

    private var header: some View {
        AppleLikeListTopRowHeader(
            image: .applicationCogOutlineIcon,
            title: L10n.Settings.AppIconShortcuts.title,
            subtitle: L10n.Settings.AppIconShortcuts.subtitle
        )
    }

    private var itemsSection: some View {
        Section {
            ForEach(viewModel.config.items, id: \.serverUniqueId) { item in
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
                Label(L10n.Settings.AppIconShortcuts.AddItem.title, systemSymbol: .plus)
            }
        } header: {
            Text(L10n.Settings.AppIconShortcuts.Items.title)
        } footer: {
            Text(L10n.Settings.AppIconShortcuts.Footer.title)
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
        NavigationLink {
            MagicItemCustomizationView(mode: .edit, context: .appIconShortcut, item: item) { updatedMagicItem in
                viewModel.updateItem(updatedMagicItem)
            }
        } label: {
            itemRow(item: item, info: info)
        }
    }

    private func itemRow(item: MagicItem, info: MagicItem.Info) -> some View {
        HStack {
            Image(uiImage: image(for: item, itemInfo: info))
            Text(item.name(info: info))
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemSymbol: .line3Horizontal)
                .foregroundStyle(.gray)
        }
    }

    private func image(for item: MagicItem, itemInfo: MagicItem.Info) -> UIImage {
        item.icon(info: itemInfo).image(
            ofSize: .init(width: 18, height: 18),
            color: .init(hex: itemInfo.customization?.iconColor)
        )
    }

    private var resetView: some View {
        Button(L10n.Settings.AppIconShortcuts.Reset.title, role: .destructive) {
            showResetConfirmation = true
        }
        .confirmationDialog(
            L10n.Settings.AppIconShortcuts.Reset.confirmationTitle,
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
    AppIconShortcutsConfigurationView()
}
