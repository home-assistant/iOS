import Shared
import SwiftUI

struct MagicItemAddView: View {
    enum Context {
        case watch
        case carPlay
        case widget
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MagicItemAddViewModel()

    let context: Context
    let itemToAdd: (MagicItem?) -> Void

    var body: some View {
        NavigationView {
            VStack {
                Picker(L10n.MagicItem.ItemType.Selection.List.title, selection: $viewModel.selectedItemType) {
                    if [.carPlay, .widget].contains(context) {
                        Text(L10n.MagicItem.ItemType.Entity.List.title)
                            .tag(MagicItemAddType.entities)
                    }
                    if context != .widget {
                        // In other context user can just select entities directly
                        // In Apple watch we don't have entity support yet
                        if context == .watch {
                            Text(L10n.MagicItem.ItemType.Script.List.title)
                                .tag(MagicItemAddType.scripts)
                            Text(L10n.MagicItem.ItemType.Scene.List.title)
                                .tag(MagicItemAddType.scenes)
                        }
                        Text(L10n.MagicItem.ItemType.Action.List.title)
                            .tag(MagicItemAddType.actions)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                List {
                    switch viewModel.selectedItemType {
                    case .actions:
                        actionsList
                    case .scripts:
                        scriptsPerServerList
                    case .scenes:
                        scenesPerServerList
                    case .entities:
                        entitiesPerServerList
                    }
                }
                .searchable(text: $viewModel.searchText)
            }
            .onAppear {
                autoSelectItemType()
                viewModel.loadContent()
            }
            .toolbar(content: {
                CloseButton {
                    dismiss()
                }
            })
        }
    }

    private func autoSelectItemType() {
        switch context {
        case .watch:
            viewModel.selectedItemType = .scripts
        case .carPlay, .widget:
            viewModel.selectedItemType = .entities
        }
    }

    @ViewBuilder
    private var actionsList: some View {
        actionsDeprecationDisclaimer
        ForEach(viewModel.actions, id: \.ID) { action in
            if visibleForSearch(title: action.Text) {
                Button(action: {
                    itemToAdd(.init(id: action.ID, serverId: action.serverIdentifier, type: .action))
                    dismiss()
                }, label: {
                    MagicItemRow(title: action.Text, imageSystemName: "plus.circle.fill")
                })
                .tint(Color(uiColor: .label))
            }
        }
    }

    private var actionsDeprecationDisclaimer: some View {
        Section {
            Button {
                viewModel.selectedItemType = .scripts
            } label: {
                Text(L10n.MagicItem.ItemType.Action.List.Warning.title)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var scriptsPerServerList: some View {
        ForEach(Array(viewModel.scripts.keys), id: \.identifier) { server in
            Section(server.info.name) {
                list(entities: viewModel.scripts[server] ?? [], serverId: server.identifier.rawValue, type: .script)
            }
        }
    }

    @ViewBuilder
    private var scenesPerServerList: some View {
        ForEach(Array(viewModel.scenes.keys), id: \.identifier) { server in
            Section(server.info.name) {
                list(entities: viewModel.scenes[server] ?? [], serverId: server.identifier.rawValue, type: .scene)
            }
        }
    }

    @ViewBuilder
    private var entitiesPerServerList: some View {
        ForEach(Array(viewModel.entities.keys), id: \.identifier) { server in
            Section(server.info.name) {
                list(entities: viewModel.entities[server] ?? [], serverId: server.identifier.rawValue, type: .entity)
            }
        }
    }

    @ViewBuilder
    private func list(entities: [HAAppEntity], serverId: String, type: MagicItem.ItemType) -> some View {
        ForEach(entities, id: \.id) { entity in
            if visibleForSearch(title: entity.name) || visibleForSearch(title: entity.entityId) {
                NavigationLink {
                    MagicItemCustomizationView(
                        mode: .add,
                        context: context,
                        item: .init(
                            id: entity.entityId,
                            serverId: serverId,
                            type: type
                        )
                    ) { itemToAdd in
                        self.itemToAdd(itemToAdd)
                        dismiss()
                    }
                } label: {
                    MagicItemRow(
                        title: entity.name,
                        subtitle: entity.entityId,
                        entityIcon: {
                            if let entityId = entity.icon {
                                return MaterialDesignIcons(serversideValueNamed: entityId, fallback: .dotsGridIcon)
                            } else {
                                return Domain(rawValue: entity.domain)?.icon ?? .dotsGridIcon
                            }
                        }()
                    )
                }
            }
        }
    }

    private func visibleForSearch(title: String) -> Bool {
        viewModel.searchText.count < 3 || title.lowercased().contains(viewModel.searchText.lowercased())
    }
}

struct MagicItemRow: View {
    // This avoids lag while loading a screen with several rows
    @State private var showIcon = false

    private let title: String
    private let subtitle: String?
    private let imageSystemName: String?
    private let entityIcon: MaterialDesignIcons?

    init(
        title: String,
        subtitle: String? = nil,
        imageSystemName: String? = nil,
        entityIcon: MaterialDesignIcons? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageSystemName = imageSystemName
        self.entityIcon = entityIcon
    }

    var body: some View {
        HStack(spacing: Spaces.one) {
            HStack {
                if showIcon, let entityIcon {
                    Image(uiImage: entityIcon.image(
                        ofSize: .init(width: 24, height: 24),
                        color: Asset.Colors.haPrimary.color
                    ))
                }
            }
            .frame(width: 24, height: 24)
            VStack {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subtitle {
                    Text(subtitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            if let imageSystemName {
                Image(systemName: imageSystemName)
                    .foregroundStyle(.white, .green)
                    .font(.title3)
            }
        }
        .animation(.easeInOut, value: showIcon)
        .onAppear {
            showIcon = true
        }
        .onDisappear {
            showIcon = false
        }
    }
}

#Preview {
    MagicItemAddView(context: .carPlay) { _ in
    }
}
