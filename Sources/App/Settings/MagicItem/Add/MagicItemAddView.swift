import SFSafeSymbols
import Shared
import SwiftUI

struct MagicItemAddView: View {
    enum Context {
        case watch
        case carPlay
        case widget
        case appIconShortcut
    }

    enum PickerOption {
        case entities
        /// Areas, reached from the watch configuration's add menu: an area entry opens the area's
        /// entities on the watch. Never offered alongside the others in the segmented picker.
        case areas
        case assistPipelines
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MagicItemAddViewModel
    @State private var selectedEntity: HAAppEntity?
    private let visiblePickerOptions: [PickerOption]
    private let allowMultipleSelection: Bool

    let context: Context
    let itemToAdd: (MagicItem?) -> Void

    init(
        context: Context,
        initialItemType: MagicItemAddType? = nil,
        visiblePickerOptions: [PickerOption]? = nil,
        allowMultipleSelection: Bool = false,
        itemToAdd: @escaping (MagicItem?) -> Void
    ) {
        self.context = context
        self.allowMultipleSelection = allowMultipleSelection
        self.itemToAdd = itemToAdd

        let resolvedPickerOptions = visiblePickerOptions ?? {
            var options: [PickerOption] = [.entities]
            if [.carPlay, .appIconShortcut].contains(context), #available(iOS 26.0, *) {
                options.append(.assistPipelines)
            }
            return options
        }()
        self.visiblePickerOptions = resolvedPickerOptions
        let resolvedInitialItemType = initialItemType ?? Self.defaultItemType(
            visiblePickerOptions: resolvedPickerOptions
        )
        self._viewModel = StateObject(wrappedValue: MagicItemAddViewModel(selectedItemType: resolvedInitialItemType))
    }

    var body: some View {
        NavigationView {
            Group {
                switch viewModel.selectedItemType {
                case .entities:
                    VStack {
                        pickerView
                            .padding(.horizontal)
                        // The watch only offers what it can display and run; other contexts show everything.
                        entitiesPerServerList(domainFilter: context == .watch ? Domain.watchAddable : nil)
                    }
                case .areas:
                    VStack {
                        pickerView
                            .padding(.horizontal)
                        AreaMagicItemAddList { area in
                            itemToAdd(area)
                            dismiss()
                        }
                    }
                case .assistPipelines:
                    VStack {
                        pickerView
                            .padding(.horizontal)
                        AssistPipelineAddList { pipeline in
                            itemToAdd(pipeline)
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
                    case .areas:
                        Text(verbatim: L10n.MagicItem.ItemType.Area.List.title)
                            .tag(MagicItemAddType.areas)
                    case .assistPipelines:
                        Text(verbatim: L10n.Widgets.Action.Name.assist)
                            .tag(MagicItemAddType.assistPipelines)
                    }
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .padding(.top)
        }
    }

    private static func defaultItemType(visiblePickerOptions: [PickerOption]) -> MagicItemAddType {
        switch visiblePickerOptions.first {
        case .entities, .none:
            return .entities
        case .areas:
            return .areas
        case .assistPipelines:
            return .assistPipelines
        }
    }

    @ViewBuilder
    private func entitiesPerServerList(domainFilter: [Domain]? = nil) -> some View {
        EntityPicker(
            selectedServerId: Current.servers.all
                .first(where: { $0.identifier.rawValue == viewModel.selectedServerId })?.identifier.rawValue,
            selectedEntity: $selectedEntity,
            domainFilter: domainFilter,
            mode: .inline,
            allowMultipleSelection: allowMultipleSelection,
            onMultipleSelectionConfirmed: { entities in
                // Two or more entities skip customization and are added with their default configuration.
                for entity in entities {
                    itemToAdd(.init(id: entity.entityId, serverId: entity.serverId, type: .entity))
                }
                dismiss()
            }
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
}

#Preview {
    MagicItemAddView(context: .carPlay) { _ in
    }
}
