import SwiftUI
import Shared

struct EntityFilterPickerView: View {

    struct PickerItem {
        let id: String
        let title: String
    }

    let title: String
    let pickerItems: [PickerItem]
    @Binding var selectedItemId: String?

    init(title: String, pickerItems: [PickerItem], selectedItemId: Binding<String?>) {
        self.title = title
        self.pickerItems = pickerItems
        self._selectedItemId = selectedItemId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Text(title)
                .font(.caption2.bold())
            Menu {
                ForEach(pickerItems, id: \.id) { item in
                    Button {
                        selectedItemId = item.id
                    } label: {
                        Text(item.title)
                    }
                }
            } label: {
                Text(pickerItems.first { $0.id == selectedItemId }?.title ?? title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(DesignSystem.Font.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignSystem.Spaces.three)
        .padding(.vertical, DesignSystem.Spaces.one)
        .frame(width: 150, alignment: .leading)
        .modify { view in
            if #available(iOS 26.0, *) {
                view.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                view.clipShape(.capsule)
            }
        }
    }
}

#Preview {
    EntityFilterPickerView(title: "Filter 1", pickerItems: [.init(id: "1", title: "Abc"), .init(id: "2", title: "Def")], selectedItemId: .constant("1"))
}
