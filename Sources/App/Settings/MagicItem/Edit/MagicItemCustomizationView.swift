import Shared
import SwiftUI

struct MagicItemCustomizationView: View {
    enum Mode {
        case add
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MagicItemCustomizationViewModel

    @State private var useCustomColors = false

    /// Context in which the screen will be presented, editing existent Magic Item or adding new
    let mode: Mode
    let context: MagicItemAddView.Context
    let addItem: (MagicItem) -> Void

    init(
        mode: Mode,
        context: MagicItemAddView.Context,
        item: MagicItem,
        addItem: @escaping (MagicItem) -> Void
    ) {
        self.mode = mode
        self.context = context
        self._viewModel = .init(wrappedValue: .init(item: item))
        self.addItem = addItem
    }

    var body: some View {
        List {
            if let info = viewModel.info {
                mainInformationView(info: info)
                customizationView(info: info)
                actionView
            }
        }
        .onChange(of: viewModel.info) { newValue in
            guard let newValue else { return }
            useCustomColors = newValue.customization?.backgroundColor != nil || newValue.customization?.textColor != nil
        }
        .onChange(of: useCustomColors) { newValue in
            if newValue {
                viewModel.item.customization?.backgroundColor = viewModel.item.customization?.backgroundColor ?? UIColor
                    .black.hexString()
                viewModel.item.customization?.textColor = viewModel.item.customization?.textColor ?? UIColor.white
                    .hexString()
            } else {
                viewModel.item.customization?.backgroundColor = nil
                viewModel.item.customization?.textColor = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                    dismiss()
                } label: {
                    Text(mode == .add ? L10n.MagicItem.add : L10n.MagicItem.edit)
                }
            }
        }
        .onAppear {
            // Avoid nil customization object to prevent state values from crash
            preventNilCustomization()
            viewModel.loadMagicInfo()
        }
    }

    private func save() {
        if Self.skipsConfirmation(context: context, item: viewModel.item) {
            viewModel.item.customization?.requiresConfirmation = false
        }

        addItem(viewModel.item)
    }

    private func mainInformationView(info: MagicItem.Info) -> some View {
        Section {
            HStack(spacing: DesignSystem.Spaces.two) {
                if viewModel.item.type == .assistPipeline {
                    let iconColor: UIColor = if let iconColorHex = viewModel.item.customization?.iconColor {
                        UIColor(Color(hex: iconColorHex))
                    } else {
                        .haPrimary
                    }
                    Image(uiImage: MaterialDesignIcons.microphoneIcon.image(
                        ofSize: .init(width: 24, height: 24),
                        color: iconColor
                    ))
                } else {
                    IconPicker(
                        selectedIcon: .init(get: {
                            viewModel.item.icon(info: info)
                        }, set: { newIcon in
                            viewModel.item.customization?.icon = newIcon?.name
                            viewModel.item.customization?.iconIsCustomized = true
                        }),
                        selectedColor: .init(get: {
                            if let iconColorHex = viewModel.item.customization?.iconColor {
                                return Color(hex: iconColorHex)
                            } else {
                                return Color.haPrimary
                            }
                        }, set: { _ in
                            /* no-op */
                        })
                    )
                }
                TextField(viewModel.item.name(info: info), text: .init(get: {
                    viewModel.item.name(info: info)
                }, set: { newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.item.displayText = nil
                    } else {
                        viewModel.item.displayText = newValue
                    }
                }))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text(verbatim: L10n.MagicItem.DisplayText.title)
        }
    }

    @ViewBuilder
    private func customizationView(info: MagicItem.Info) -> some View {
        Section {
            // Seeding the picker is a read, so it must not write the seed back: an entity only
            // drops the color the frontend gives it once the user actually picks one here.
            ColorPicker(L10n.MagicItem.IconColor.title, selection: .init(get: {
                if let configIconColor = viewModel.item.customization?.iconColor {
                    return Color(hex: configIconColor)
                }
                return Color.haPrimary
            }, set: { newColor in
                viewModel.item.customization?.iconColor = newColor.hex()
                viewModel.item.customization?.iconColorIsCustomized = true
            }), supportsOpacity: false)
            if context != .carPlay {
                Toggle(L10n.MagicItem.UseCustomColors.title, isOn: $useCustomColors)
                if useCustomColors {
                    ColorPicker(L10n.MagicItem.BackgroundColor.title, selection: .init(get: {
                        Color(hex: viewModel.item.customization?.backgroundColor)
                    }, set: { newColor in
                        viewModel.item.customization?.backgroundColor = newColor.hex()
                    }), supportsOpacity: false)
                    ColorPicker(L10n.MagicItem.TextColor.title, selection: .init(get: {
                        Color(hex: viewModel.item.customization?.textColor)
                    }, set: { newColor in
                        viewModel.item.customization?.textColor = newColor.hex()
                    }), supportsOpacity: false)
                }
            }
        }
    }

    @ViewBuilder
    private var actionView: some View {
        if [.widget, .appIconShortcut].contains(context) {
            Section {
                // A widget tile has two halves to tap, the way the frontend's tile card does: the
                // icon and everything around it. An app icon shortcut is a single action, so it
                // only offers the one behavior.
                if context == .widget {
                    MagicItemActionSelectionView(
                        title: L10n.MagicItem.Action.tapBehavior,
                        serverId: viewModel.item.serverId,
                        defaultAction: viewModel.item.defaultTapAction,
                        canToggle: viewModel.item.canToggle,
                        action: $viewModel.item.tapAction
                    )
                }
                // An app icon shortcut runs what the widget icon would, so both name the same default.
                MagicItemActionSelectionView(
                    title: context == .widget ? L10n.MagicItem.Action.iconTapBehavior : L10n.MagicItem.Action.onTap,
                    serverId: viewModel.item.serverId,
                    defaultAction: viewModel.item.defaultIconAction,
                    canToggle: viewModel.item.canToggle,
                    action: $viewModel.item.action
                )
            } header: {
                Text(verbatim: L10n.MagicItem.action)
            } footer: {
                if context == .widget {
                    Text(verbatim: L10n.MagicItem.Action.footer)
                }
            }
        }
        // A watch sensor is only displayed — tapping it opens its details screen and runs nothing,
        // so there is no action to confirm. Neither does an area entry, which opens the area's
        // entities.
        if !Self.skipsConfirmation(context: context, item: viewModel.item),
           viewModel.item.type != .area,
           !(context == .watch && viewModel.item.isWatchDisplayOnly) {
            Section {
                Toggle(L10n.MagicItem.RequireConfirmation.title, isOn: .init(get: {
                    viewModel.item.customization?.requiresConfirmation ?? false
                }, set: { newValue in
                    viewModel.item.customization?.requiresConfirmation = newValue
                }))
            } footer: {
                if context == .widget {
                    Text(verbatim: L10n.Widgets.Custom.RequireConfirmation.footer)
                }
            }
        }
    }

    /// An Assist item in CarPlay or on the watch starts an Assist session instead of running a
    /// service, so asking for confirmation first has nothing to confirm — and `MagicItemProvider`
    /// clears the flag on both Assist types anyway.
    private static func skipsConfirmation(context: MagicItemAddView.Context, item: MagicItem) -> Bool {
        [.carPlay, .watch].contains(context) && item.isAssist
    }

    private func preventNilCustomization() {
        if viewModel.item.customization == nil {
            viewModel.item.customization = .init()
        }
    }
}

#Preview {
    MagicItemCustomizationView(
        mode: .add,
        context: .widget,
        item: .init(id: "script.unlock_door", serverId: "1", type: .script)
    ) { _ in
    }
}
