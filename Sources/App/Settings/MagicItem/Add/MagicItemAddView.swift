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
        case scriptsScenesAutomations
        case assistPipelines
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MagicItemAddViewModel()
    @State private var selectedEntity: HAAppEntity?
    private let visiblePickerOptions: [PickerOption]
    private let initialItemType: MagicItemAddType

    let context: Context
    let itemToAdd: (MagicItem?) -> Void

    init(
        context: Context,
        initialItemType: MagicItemAddType? = nil,
        visiblePickerOptions: [PickerOption]? = nil,
        itemToAdd: @escaping (MagicItem?) -> Void
    ) {
        self.context = context
        self.itemToAdd = itemToAdd

        let resolvedPickerOptions = visiblePickerOptions ?? {
            var options: [PickerOption] = []
            if [.carPlay, .widget, .appIconShortcut].contains(context) {
                options.append(.entities)
            }
            if context != .widget {
                // In other context user can just select entities directly
                // In Apple watch we don't have entity support yet
                if context == .watch {
                    options.append(.scriptsScenesAutomations)
                }
            }
            if [.carPlay, .appIconShortcut].contains(context), #available(iOS 26.0, *) {
                options.append(.assistPipelines)
            }
            return options
        }()
        self.visiblePickerOptions = resolvedPickerOptions
        self.initialItemType = initialItemType ?? Self.defaultItemType(
            for: context,
            visiblePickerOptions: resolvedPickerOptions
        )
    }

    var body: some View {
        NavigationView {
            Group {
                switch viewModel.selectedItemType {
                case .entities:
                    VStack {
                        pickerView
                            .padding(.horizontal)
                        entitiesPerServerList()
                    }
                case .scriptsScenesAutomations:
                    VStack {
                        pickerView
                            .padding(.horizontal)
                        entitiesPerServerList(domainFilter: [.script, .scene, .automation])
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
                autoSelectItemType()

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
                    .presentationDetents([.large])
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
                    case .scriptsScenesAutomations:
                        Text(verbatim: L10n.MagicItem.ItemType.ScriptsScenesAutomations.List.title)
                            .tag(MagicItemAddType.scriptsScenesAutomations)
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

    private func autoSelectItemType() {
        viewModel.selectedItemType = initialItemType
    }

    private static func defaultItemType(
        for context: Context,
        visiblePickerOptions: [PickerOption]
    ) -> MagicItemAddType {
        if let firstOption = visiblePickerOptions.first {
            switch firstOption {
            case .entities:
                return .entities
            case .scriptsScenesAutomations:
                return .scriptsScenesAutomations
            case .assistPipelines:
                return .assistPipelines
            }
        }

        switch context {
        case .watch:
            return .scriptsScenesAutomations
        case .carPlay, .widget, .appIconShortcut:
            return .entities
        }
    }

    @ViewBuilder
    private func entitiesPerServerList(domainFilter: [Domain]? = nil) -> some View {
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
}

#Preview {
    MagicItemAddView(context: .carPlay) { _ in
    }
}
