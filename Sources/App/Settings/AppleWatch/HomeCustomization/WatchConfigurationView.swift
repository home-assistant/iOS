import Shared
import SwiftUI

struct WatchConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WatchConfigurationViewModel()

    @State private var isLoaded = false
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Apple Watch")
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
        }
        .interactiveDismissDisabled(true)
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.watchConfig.assist.serverId) { newValue in
            viewModel.loadPipelines(for: newValue)
        }
        .sheet(isPresented: $viewModel.showAddItem, content: {
            MagicItemAddView { itemToAdd in
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
            resetView
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

    private var itemsSection: some View {
        Section(L10n.Watch.Configuration.Items.title) {
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
                Label(L10n.Watch.Configuration.AddItem.title, systemImage: "plus")
            }
        }
    }

    private var assistSection: some View {
        Section("Assist") {
            Toggle(isOn: $viewModel.watchConfig.assist.showAssist, label: {
                Text(L10n.Watch.Configuration.ShowAssist.title)
            })
            if viewModel.watchConfig.assist.showAssist {
                Picker(L10n.Watch.Config.Assist.selectServer, selection: $viewModel.watchConfig.assist.serverId) {
                    ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                        Text(server.info.name)
                            .tag(server.identifier.rawValue)
                    }
                }
                Picker(L10n.Watch.Labels.SelectedPipeline.title, selection: $viewModel.watchConfig.assist.pipelineId) {
                    ForEach(viewModel.assistPipelines, id: \.id) { pipeline in
                        Text(pipeline.name)
                            .tag(pipeline.id)
                    }
                }
            }
        }
    }

    private var watchPreview: some View {
        ZStack {
            watchItemsList
                .offset(x: -10)
            Image("watch-frame")
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
                ForEach(viewModel.watchConfig.items, id: \.id) { item in
                    makeWatchItem(item: item)
                }
                if viewModel.watchConfig.items.isEmpty {
                    noItemsWatchView
                }
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

    private func makeWatchItem(item: MagicItem) -> some View {
        let itemInfo = viewModel.magicItemInfo(for: item)

        return HStack(spacing: Spaces.one) {
            VStack {
                Image(uiImage: image(for: item, itemInfo: itemInfo, watchPreview: true))
                    .foregroundColor(Color(uiColor: .init(hex: itemInfo.customization?.iconColor)))
                    .padding(Spaces.one)
            }
            .background(Color(uiColor: .init(hex: itemInfo.customization?.iconColor)).opacity(0.3))
            .clipShape(Circle())
            Text(itemInfo.name)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(textColorForWatchItem(itemInfo: itemInfo))
        }
        .padding(Spaces.one)
        .frame(width: 190, height: 55)
        .background(backgroundForWatchItem(itemInfo: itemInfo))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, -Spaces.one)
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

    private var watchStatusBar: some View {
        ZStack(alignment: .trailing) {
            Text("9:41")
                .font(.system(size: 14).bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top)
            if viewModel.watchConfig.assist.showAssist {
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
        .animation(.bouncy, value: viewModel.watchConfig.assist.showAssist)
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
    VStack {
        Text("Abc")
            .sheet(isPresented: .constant(true), content: {
                WatchConfigurationView()
            })
    }
}
