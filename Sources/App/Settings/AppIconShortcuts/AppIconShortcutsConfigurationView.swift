import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

struct AppIconShortcutsConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AppIconShortcutsConfigurationViewModel

    @State private var isLoaded = false
    @State private var showResetConfirmation = false
    @State private var isEditingItems = false

    init(viewModel: AppIconShortcutsConfigurationViewModel? = nil) {
        self._viewModel = .init(wrappedValue: viewModel ?? AppIconShortcutsConfigurationViewModel())
    }

    var body: some View {
        List {
            header
            itemsSection
            resetView
            DebugDatabaseTransferSection(part: .appIconShortcuts) {
                viewModel.loadConfig()
            }
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
        .listTopContentMargin()
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
            ReorderableSectionHeader(
                title: L10n.Settings.AppIconShortcuts.Items.title,
                isEditing: $isEditingItems
            )
        } footer: {
            Text(L10n.Settings.AppIconShortcuts.Footer.title)
        }
    }

    private func makeListItem(item: MagicItem) -> some View {
        NavigationLink {
            MagicItemCustomizationView(mode: .edit, context: .appIconShortcut, item: item) { updatedMagicItem in
                viewModel.updateItem(updatedMagicItem)
            }
        } label: {
            MagicItemConfigurationRow(
                item: item,
                info: viewModel.magicItemInfo(for: item),
                isReorderIndicatorVisible: isEditingItems
            )
        }
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

extension AppIconShortcutsConfigurationView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Settings.AppIconShortcuts.Items.title),
            SettingsSearchEntry(L10n.Settings.AppIconShortcuts.AddItem.title),
            SettingsSearchEntry(L10n.Settings.AppIconShortcuts.Reset.title),
        ]
    }
}
