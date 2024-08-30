import Shared
import SwiftUI

struct MagicItemCustomizationView: View {
    enum Mode {
        case add
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MagicItemEditViewModel

    @State private var iconColor: Color = .init(uiColor: Asset.Colors.haPrimary.color)
    @State private var textColor: Color = .white
    @State private var backgroundColor: Color = .black
    @State private var requiresConfirmation = false
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
                }

                Section {
                    ColorPicker(L10n.MagicItem.IconColor.title, selection: $iconColor)
                    Toggle(L10n.MagicItem.UseCustomColors.title, isOn: $useCustomColors)
                    if useCustomColors {
                        ColorPicker(L10n.MagicItem.BackgroundColor.title, selection: $backgroundColor)
                        ColorPicker(L10n.MagicItem.TextColor.title, selection: $textColor)
                    }
                }

                Section {
                    Toggle(L10n.MagicItem.RequireConfirmation.title, isOn: $requiresConfirmation)
                }
            }
        }
        .onChange(of: viewModel.info) { newValue in
            guard let newValue else { return }
            if let iconColor = newValue.customization?.iconColor {
                self.iconColor = Color(uiColor: .init(hex: iconColor))
            }
            if let backgroundColor = newValue.customization?.backgroundColor {
                self.backgroundColor = Color(uiColor: .init(hex: backgroundColor))
            }
            if let textColor = newValue.customization?.textColor {
                self.textColor = Color(uiColor: .init(hex: textColor))
            }
            useCustomColors = newValue.customization?.backgroundColor != nil || newValue.customization?.textColor != nil
            requiresConfirmation = newValue.customization?.requiresConfirmation ?? true
        }
        .toolbar {
            Button {
                viewModel.item.customization = .init(
                    iconColor: UIColor(iconColor).hexString(),
                    textColor: useCustomColors ? UIColor(textColor).hexString() : nil,
                    backgroundColor: useCustomColors ? UIColor(backgroundColor).hexString() : nil,
                    requiresConfirmation: requiresConfirmation
                )
                addItem(viewModel.item)
                dismiss()
            } label: {
                Text(mode == .add ? L10n.MagicItem.add : L10n.MagicItem.edit)
            }
        }
        .onAppear {
            viewModel.loadMagicInfo()
        }
    }
}

#Preview {
    MagicItemCustomizationView(mode: .add, item: .init(id: "script.unlock_door", serverId: "1", type: .script)) { _ in
    }
}
