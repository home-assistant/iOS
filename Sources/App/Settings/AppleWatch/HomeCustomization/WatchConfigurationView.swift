import SFSafeSymbols
import Shared
import StoreKit
import SwiftUI

struct WatchConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @StateObject private var viewModel: WatchConfigurationViewModel

    @State private var isLoaded = false
    @State private var showResetConfirmation = false
    @State private var showAddFolderSheet = false
    @State private var newFolderName: String = L10n.Watch.Configuration.Folder.defaultName

    private let needsNavigationController: Bool

    init(needsNavigationController: Bool = false, viewModel: WatchConfigurationViewModel? = nil) {
        self.needsNavigationController = needsNavigationController
        self._viewModel = .init(wrappedValue: viewModel ?? WatchConfigurationViewModel())
    }

    var body: some View {
        if needsNavigationController {
            NavigationStack {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .watchVariantIcon,
                title: L10n.Watch.Configuration.Header.title,
                subtitle: L10n.Watch.Configuration.Header.subtitle
            )
            .onAppear {
                // Prevent trigger when popping nav controller
                guard !isLoaded else { return }
                viewModel.loadWatchConfig()
                isLoaded = true
            }
            layoutSection
            itemsSection
            assistSection
            resetView
            DebugDatabaseTransferSection(part: .watchConfiguration) {
                viewModel.loadWatchConfig()
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Apple Watch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    let success = viewModel.save()
                    if success {
                        requestReview()
                        dismiss()
                    }
                }, label: {
                    Text(verbatim: L10n.Watch.Configuration.Save.title)
                })
            }
        })
        .sheet(isPresented: $viewModel.showAddItem, content: {
            MagicItemAddView(context: .watch) { itemToAdd in
                guard let itemToAdd else { return }
                viewModel.addItem(itemToAdd)
            }
            .preferredColorScheme(.dark)
        })
        .alert(viewModel.errorMessage ?? L10n.errorLabel, isPresented: $viewModel.showError) {
            Button(action: {}, label: {
                Text(verbatim: L10n.okLabel)
            })
        }
        .sheet(isPresented: $showAddFolderSheet) {
            addFolderSheet
        }
    }

    private var resetView: some View {
        Button(L10n.Watch.Debug.DeleteDb.Reset.title, role: .destructive) {
            showResetConfirmation = true
        }
        .confirmationDialog(
            L10n.Watch.Debug.DeleteDb.Alert.title,
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

    private var layoutSection: some View {
        Section {
            Picker(L10n.Watch.Configuration.Layout.title, selection: Binding(
                get: { viewModel.watchConfig.resolvedLayout },
                set: { viewModel.watchConfig.layout = $0 }
            )) {
                ForEach(WatchLayout.allCases, id: \.rawValue) { layout in
                    Text(layout.name).tag(layout)
                }
            }
        } footer: {
            Text(verbatim: L10n.Watch.Configuration.Layout.footer)
        }
    }

    private var itemsSection: some View {
        Section(L10n.Watch.Configuration.Items.title) {
            ForEach(viewModel.watchConfig.items, id: \.serverUniqueId) { item in
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
            Button {
                newFolderName = ""
                showAddFolderSheet = true
            } label: {
                Label(L10n.Watch.Configuration.AddFolder.title, systemSymbol: .folder)
            }
        }
    }

    @ViewBuilder
    private var addFolderSheet: some View {
        NavigationStack {
            addFolderForm
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private var addFolderForm: some View {
        Form {
            Section(L10n.Watch.Configuration.FolderName.title) {
                TextField(L10n.Watch.Configuration.Folder.defaultName, text: $newFolderName)
                    .textInputAutocapitalization(.words)
            }
        }
        .navigationTitle(L10n.Watch.Configuration.NewFolder.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { showAddFolderSheet = false }) {
                    Text(L10n.cancelLabel)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    viewModel.addFolder(
                        named: name.isEmpty ? L10n.Watch.Configuration.Folder.defaultName : name
                    )
                    showAddFolderSheet = false
                }) {
                    Text(L10n.Watch.Configuration.AddFolder.title)
                }
            }
        }
    }

    private var assistSection: some View {
        Section("Assist") {
            Toggle(isOn: $viewModel.watchConfig.assist.showAssist, label: {
                Text(verbatim: L10n.Watch.Configuration.ShowAssist.title)
            })
            if viewModel.watchConfig.assist.showAssist {
                HStack {
                    Text(L10n.Watch.Labels.SelectedPipeline.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    AssistPipelinePicker(
                        selectedServerId: $viewModel.watchConfig.assist.serverId,
                        selectedPipelineId: $viewModel.watchConfig.assist.pipelineId
                    )
                }
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
        if item.type == .folder {
            NavigationLink {
                FolderDetailView(
                    folderId: item.id,
                    viewModel: viewModel
                )
                .environment(\.colorScheme, .dark)
            } label: {
                itemRow(item: item, info: info)
            }
        } else {
            NavigationLink {
                MagicItemCustomizationView(mode: .edit, context: .watch, item: item) { updatedMagicItem in
                    viewModel.updateItem(updatedMagicItem)
                }
                .environment(\.colorScheme, .dark)
            } label: {
                itemRow(item: item, info: info)
            }
        }
    }

    private func itemRow(item: MagicItem, info: MagicItem.Info) -> some View {
        HStack {
            Image(uiImage: image(for: item, itemInfo: info, color: .haPrimary))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name(info: info))
                if let contextSubtitle = info.contextSubtitle {
                    Text(contextSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemSymbol: .line3Horizontal)
                .foregroundStyle(.gray)
        }
    }

    private func image(
        for item: MagicItem,
        itemInfo: MagicItem.Info,
        color: UIColor? = nil
    ) -> UIImage {
        let icon: MaterialDesignIcons = item.icon(info: itemInfo)
        let resolvedColor: UIColor = if let color {
            color
        } else if let iconColor = item.customization?.iconColor ?? itemInfo.customization?.iconColor {
            .init(hex: iconColor)
        } else {
            .haPrimary
        }

        return icon.image(
            ofSize: .init(width: 18, height: 18),
            color: resolvedColor
        )
    }
}

#Preview {
    VStack {
        Text("Abc")
            .sheet(isPresented: .constant(true), content: {
                WatchConfigurationView()
            })
    }
}

extension WatchConfigurationView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Watch.Configuration.Layout.title),
            SettingsSearchEntry(L10n.Watch.Configuration.Items.title),
            SettingsSearchEntry(L10n.Watch.Configuration.AddItem.title),
            SettingsSearchEntry(L10n.Watch.Configuration.AddFolder.title),
            SettingsSearchEntry(L10n.Watch.Configuration.ShowAssist.title),
            SettingsSearchEntry(L10n.Watch.Labels.SelectedPipeline.title),
        ]
    }
}
