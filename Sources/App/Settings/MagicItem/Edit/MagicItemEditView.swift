import Shared
import SwiftUI

struct MagicItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MagicItemEditViewModel

    @State private var iconColor: Color = .init(uiColor: Asset.Colors.haPrimary.color)
    @State private var textColor: Color = .white
    @State private var backgroundColor: Color = .black
    @State private var requiresConfirmation = false
    @State private var useCustomColors = false

    let addItem: (MagicItem) -> Void

    init(item: MagicItem, addItem: @escaping (MagicItem) -> Void) {
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
                Text(L10n.MagicItem.add)
            }
        }
        .onAppear {
            viewModel.loadMagicInfo()
        }
    }
}

#Preview {
    MagicItemEditView(item: .init(id: "script.unlock_door", serverId: "1", type: .script)) { _ in
    }
}
