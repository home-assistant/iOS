import Shared
import SwiftUI

struct MagicItemCustomizationView: View {
    enum Mode {
        case add
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MagicItemEditViewModel

    @State private var useCustomColors = false

    /// Context in which the screen will be presented, editing existent Magic Item or adding new
    let mode: Mode
    let addItem: (MagicItem) -> Void

    init(
        mode: Mode,
        item: MagicItem,
        addItem: @escaping (MagicItem) -> Void
    ) {
        self.mode = mode
        self._viewModel = .init(wrappedValue: .init(item: item))
        self.addItem = addItem
    }

    var body: some View {
        List {
            if let info = viewModel.info {
                Section {
                    HStack {
                        Text(L10n.MagicItem.Name.title)
                        Text(info.name)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    HStack {
                        Text(L10n.MagicItem.IconName.title)
                        Text(info.iconName)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } footer: {
                    if viewModel.item.type == .script {
                        Text(L10n.MagicItem.NameAndIcon.footer)
                    }
                    if viewModel.item.type == .scene {
                        Text(L10n.MagicItem.NameAndIcon.Footer.scenes)
                    }
                }

                Section {
                    ColorPicker(L10n.MagicItem.IconColor.title, selection: .init(get: {
                        var color = Color(uiColor: Asset.Colors.haPrimary.color)
                        if let configIconColor = viewModel.item.customization?.iconColor {
                            color = Color(hex: configIconColor)
                        } else {
                            viewModel.item.customization?.iconColor = color.hex()
                        }
                        return color
                    }, set: { newColor in
                        viewModel.item.customization?.iconColor = newColor.hex()
                    }), supportsOpacity: false)
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

                Section {
                    Toggle(L10n.MagicItem.RequireConfirmation.title, isOn: .init(get: {
                        viewModel.item.customization?.requiresConfirmation ?? true
                    }, set: { newValue in
                        viewModel.item.customization?.requiresConfirmation = newValue
                    }))
                }
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
            Button {
                addItem(viewModel.item)
                dismiss()
            } label: {
                Text(mode == .add ? L10n.MagicItem.add : L10n.MagicItem.edit)
            }
        }
        .onAppear {
            // Avoid nil customization object to prevent state values from crash
            preventNilCustomization()
            viewModel.loadMagicInfo()
        }
    }

    private func preventNilCustomization() {
        if viewModel.item.customization == nil {
            viewModel.item.customization = .init()
        }
    }
}

#Preview {
    MagicItemCustomizationView(mode: .add, item: .init(id: "script.unlock_door", serverId: "1", type: .script)) { _ in
    }
}
