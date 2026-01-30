import SFSafeSymbols
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
    @State private var selectedEntity: HAAppEntity?
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
            Group {
                switch viewModel.selectedItemType {
                case .actions:
                    List {
                        pickerView
                        actionsList
                    }
                    .searchable(text: $viewModel.searchText)
                case .entities:
                    VStack {
                        pickerView
                            .padding(.horizontal)
                        entitiesPerServerList()
                    }
                case .scripts:
                    VStack {
                        pickerView
                            .padding(.horizontal)
                        entitiesPerServerList(domainFilter: .script)
                    }
                case .scenes:
                    VStack {
                        pickerView
                            .padding(.horizontal)
                        entitiesPerServerList(domainFilter: .scene)
                    }
                }
            }
            .onAppear {
                autoSelectItemType()
                viewModel.loadContent()

                if viewModel.selectedServerId == nil {
                    viewModel.selectedServerId = Current.servers.all.first?.identifier.rawValue
                }
            }
            #if targetEnvironment(macCatalyst)
            .toolbar(content: {
                CloseButton {
                    dismiss()
                }
            })
            #endif
        }
        .navigationViewStyle(.stack)
        .modify { view in
            if #available(iOS 16.0, *) {
                view
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                view
            }
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
            .listRowBackground(Color.clear)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .padding(.top)
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
                    EntityRowView(optionalTitle: action.Text, accessoryImageSystemSymbol: .plusCircleFill)
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
    private func entitiesPerServerList(domainFilter: Domain? = nil) -> some View {
        EntityPicker(
            selectedServerId: Current.servers.all
                .first(where: { $0.identifier.rawValue == viewModel.selectedServerId })?.identifier.rawValue,
            selectedEntity: $selectedEntity,
            domainFilter: domainFilter,
            mode: .inline
        )
        .background(
            NavigationLink("", isActive: .init(get: {
                selectedEntity != nil
            }, set: { _ in
                selectedEntity = nil
            })) {
                if let selectedEntity {
                    MagicItemCustomizationView(
                        mode: .add,
                        context: context,
                        item: .init(
                            id: selectedEntity.entityId,
                            serverId: selectedEntity.serverId,
                            type: .entity
                        )
                    ) { itemToAdd in
                        self.itemToAdd(itemToAdd)
                        dismiss()
                    }
                }
            }
        )
    }

    private func visibleForSearch(title: String, entityId: String) -> Bool {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            title.lowercased().contains(viewModel.searchText.lowercased()) ||
            entityId.lowercased().contains(viewModel.searchText.lowercased())
    }
}

#Preview {
    MagicItemAddView(context: .carPlay) { _ in
    }
}
