import Shared
import SwiftUI

struct MagicItemAddView: View {
    enum Context {
        case watch
        case carPlay
        case widget
    }

    enum PickerOption {
        case entities
        case scripts
        case scenes
        case legacyiOSActions
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MagicItemAddViewModel()
    private let visiblePickerOptions: [PickerOption]

    let context: Context
    let itemToAdd: (MagicItem?) -> Void

    init(context: Context, itemToAdd: @escaping (MagicItem?) -> Void) {
        self.context = context
        self.itemToAdd = itemToAdd

        self.visiblePickerOptions = {
            var options: [PickerOption] = []
            if [.carPlay, .widget].contains(context) {
                options.append(.entities)
            }
            if context != .widget {
                // In other context user can just select entities directly
                // In Apple watch we don't have entity support yet
                if context == .watch {
                    options.append(.scripts)
                    options.append(.scenes)
                }
                options.append(.legacyiOSActions)
            }
            return options
        }()
    }

    var body: some View {
        NavigationView {
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
            .safeAreaInset(edge: .top, content: {
                pickerView
            })
            .onAppear {
                autoSelectItemType()
                viewModel.loadContent()

                if viewModel.selectedServerId == nil {
                    viewModel.selectedServerId = Current.servers.all.first?.identifier.rawValue
                }
            }
            .toolbar(content: {
                CloseButton {
                    dismiss()
                }
            })
        }
    }

    @ViewBuilder
    private var pickerView: some View {
        // If there is only one option, don't show the picker
        if visiblePickerOptions.count > 1 {
            Picker(L10n.MagicItem.ItemType.Selection.List.title, selection: $viewModel.selectedItemType) {
                ForEach(visiblePickerOptions, id: \.self) { option in
                    switch option {
                    case .entities:
                        Text(verbatim: L10n.MagicItem.ItemType.Entity.List.title)
                            .tag(MagicItemAddType.entities)
                    case .legacyiOSActions:
                        Text(verbatim: L10n.MagicItem.ItemType.Action.List.title)
                            .tag(MagicItemAddType.actions)
                    case .scripts:
                        Text(verbatim: L10n.MagicItem.ItemType.Script.List.title)
                            .tag(MagicItemAddType.scripts)
                    case .scenes:
                        Text(verbatim: L10n.MagicItem.ItemType.Scene.List.title)
                            .tag(MagicItemAddType.scenes)
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding()
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
            if visibleForSearch(title: action.Text, entityId: action.ID) {
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
                Text(verbatim: L10n.MagicItem.ItemType.Action.List.Warning.title)
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
        ServersPickerPillList(selectedServerId: $viewModel.selectedServerId)
        if let server = Current.servers.all
            .first(where: { $0.identifier.rawValue == viewModel.selectedServerId }) ?? Current.servers.all.first {
            list(entities: viewModel.entities[server] ?? [], serverId: server.identifier.rawValue, type: .entity)
        }
    }

    @ViewBuilder
    private func list(entities: [HAAppEntity], serverId: String, type: MagicItem.ItemType) -> some View {
        ForEach(entities.filter({ entity in
            visibleForSearch(title: entity.name, entityId: entity.entityId)
        }), id: \.id) { entity in
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
                        if let entityIconName = entity.icon {
                            return MaterialDesignIcons(serversideValueNamed: entityIconName, fallback: .dotsGridIcon)
                        } else {
                            return Domain(rawValue: entity.domain)?
                                .icon(deviceClass: entity.deviceClass.rawValue) ?? .dotsGridIcon
                        }
                    }()
                )
            }
        }
    }

    private func visibleForSearch(title: String, entityId: String) -> Bool {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            title.lowercased().contains(viewModel.searchText.lowercased()) ||
            entityId.lowercased().contains(viewModel.searchText.lowercased())
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
                        color: UIColor(Color.haPrimary)
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
