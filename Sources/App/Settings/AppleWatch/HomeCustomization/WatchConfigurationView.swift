import SFSafeSymbols
import Shared
import StoreKit
import SwiftUI
import UniformTypeIdentifiers

struct WatchConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WatchConfigurationViewModel()

    @State private var isLoaded = false
    @State private var showResetConfirmation = false
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showImportPicker = false
    @State private var showImportConfirmation = false
    @State private var importURL: URL?

    var body: some View {
        content
            .navigationTitle("Apple Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
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
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareActivityView(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.init(filenameExtension: "homeassistant") ?? .json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    if let url = urls.first {
                        importURL = url
                        showImportConfirmation = true
                    }
                case let .failure(error):
                    Current.Log.error("File import failed: \(error.localizedDescription)")
                    viewModel.showError = true
                }
            }
            .alert(L10n.CarPlay.Import.Confirmation.title, isPresented: $showImportConfirmation) {
                Button(L10n.yesLabel, role: .destructive) {
                    if let url = importURL {
                        viewModel.importConfiguration(from: url) { success in
                            if success {
                                viewModel.loadWatchConfig()
                            }
                        }
                    }
                }
                Button(L10n.noLabel, role: .cancel) {}
            } message: {
                Text(L10n.CarPlay.Import.Confirmation.message)
            }
    }

    private var content: some View {
        List {
            watchPreview
                .listRowBackground(Color.clear)
                .onAppear {
                    // Prevent trigger when popping nav controller
                    guard !isLoaded else { return }
                    viewModel.loadWatchConfig()
                    isLoaded = true
                }
            itemsSection
            assistSection
            exportImportSection
            resetView
        }
        .preferredColorScheme(.dark)
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

    private var exportImportSection: some View {
        Section {
            Button {
                if let url = viewModel.exportConfiguration() {
                    exportedFileURL = url
                    showShareSheet = true
                }
            } label: {
                Label(L10n.CarPlay.Export.Button.title, systemSymbol: .squareAndArrowUp)
            }

            Button {
                showImportPicker = true
            } label: {
                Label(L10n.CarPlay.Import.Button.title, systemSymbol: .squareAndArrowDown)
            }
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

    private var watchPreview: some View {
        ZStack {
            watchItemsList
                .offset(x: -10)
            Image(.watchFrame)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 260)
                .foregroundStyle(.clear, Color(hue: 0, saturation: 0, brightness: 0.2))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var watchItemsList: some View {
        ZStack(alignment: .top) {
            List {
                VStack {}.padding(.top, 40)
                Group {
                    ForEach(viewModel.watchConfig.items, id: \.serverUniqueId) { item in
                        makeWatchItem(item: item)
                    }
                    if viewModel.watchConfig.items.isEmpty {
                        noItemsWatchView
                    }
                }
                .listRowSeparator(.hidden)
                .listRowSpacing(DesignSystem.Spaces.half)
            }
            .animation(.default, value: viewModel.watchConfig.items)
            .listStyle(.plain)
            .frame(width: 200, height: 265)
            .offset(x: 5, y: 10)
            watchStatusBar
                .offset(y: 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 62))
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
                MagicItemCustomizationView(mode: .edit, context: .watch, item: item) { updatedMagicItem in
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
            Text(item.name(info: info))
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemSymbol: .line3Horizontal)
                .foregroundStyle(.gray)
        }
    }

    private func makeWatchItem(item: MagicItem) -> some View {
        let itemInfo = viewModel.magicItemInfo(for: item) ?? .init(
            id: item.id,
            name: item.id,
            iconName: "",
            customization: nil
        )

        return HStack(spacing: DesignSystem.Spaces.one) {
            VStack {
                Image(uiImage: image(for: item, itemInfo: itemInfo, watchPreview: true))
                    .foregroundColor(Color(uiColor: .init(hex: itemInfo.customization?.iconColor)))
                    .padding(DesignSystem.Spaces.one)
            }
            .background(Color(uiColor: .init(hex: itemInfo.customization?.iconColor)).opacity(0.3))
            .clipShape(Circle())
            Text(item.name(info: itemInfo))
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(textColorForWatchItem(itemInfo: itemInfo))
        }
        .padding(DesignSystem.Spaces.one)
        .frame(width: 190, height: 55)
        .background(backgroundForWatchItem(itemInfo: itemInfo))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, -DesignSystem.Spaces.one)
        .listRowSeparator(.hidden)
    }

    private func backgroundForWatchItem(itemInfo: MagicItem.Info) -> Color {
        if let backgroundColor = itemInfo.customization?.backgroundColor {
            Color(uiColor: .init(hex: backgroundColor))
        } else {
            Color.gray.opacity(0.3)
        }
    }

    private func textColorForWatchItem(itemInfo: MagicItem.Info) -> Color {
        if let textColor = itemInfo.customization?.textColor {
            Color(uiColor: .init(hex: textColor))
        } else {
            Color.white
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

    private var watchStatusBar: some View {
        ZStack(alignment: .trailing) {
            Text("9:41")
                .font(.system(size: 14).bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top)
            if viewModel.watchConfig.assist.showAssist {
                Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                    ofSize: .init(width: 18, height: 18),
                    color: .haPrimary
                ))
                .padding(Spaces.one)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 25.0))
                .offset(x: -22)
                .padding(.top)
            }
        }
        .animation(.bouncy, value: viewModel.watchConfig.assist.showAssist)
        .frame(width: 210, height: 50)
        .background(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
    }

    private var noItemsWatchView: some View {
        Text(verbatim: L10n.Watch.Settings.NoItems.Phone.title)
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.footnote)
            .padding(Spaces.one)
            .background(.gray.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadiusSizes.one))
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
