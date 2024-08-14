import SwiftUI
import Shared

struct MagicItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MagicItemEditViewModel
    
    @State private var iconColor: Color = .init(uiColor: Asset.Colors.haPrimary.color)

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
                        Text("Name")
                        Text(info.name)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    HStack {
                        Text("Icon name")
                        Text(info.iconName)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } footer: {
                    if viewModel.item.type == .script {
                        Text("Edit script name and icon in frontend under 'Settings' > 'Automations & scenes' > 'Scripts'.")
                    }
                }

                HStack {
                    ColorPicker("Icon Color", selection: $iconColor)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar {
            Button {
                viewModel.item.customization = .init(iconColor: UIColor(iconColor).hexString())
                addItem(viewModel.item)
                dismiss()
            } label: {
                Text("Add")
            }

        }
        .onAppear {
            viewModel.loadMagicInfo()
        }
    }
}

#Preview {
    MagicItemEditView(item: .init(id: "script.unlock_door", type: .script)) { _ in

    }
}
