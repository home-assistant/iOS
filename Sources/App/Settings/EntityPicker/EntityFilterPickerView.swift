import Shared
import SwiftUI

struct EntityFilterPickerView: View {
    enum Style {
        case compact
        case descriptionContent
    }

    struct PickerItem {
        let id: String
        let title: String
    }

    let title: String
    let pickerItems: [PickerItem]
    @Binding var selectedItemId: String?
    let style: Style

    init(title: String, pickerItems: [PickerItem], selectedItemId: Binding<String?>, style: Style = .compact) {
        self.title = title
        self.pickerItems = pickerItems
        self._selectedItemId = selectedItemId
        self.style = style
    }

    var body: some View {
        switch style {
        case .compact:
            compactContent
        case .descriptionContent:
            descriptionContent
        }
    }

    var compactContent: some View {
        Picker(selection: Binding(
            get: { selectedItemId ?? "" },
            set: { newValue in selectedItemId = newValue.isEmpty ? nil : newValue }
        ), label: Text(pickerItems.first { $0.id == selectedItemId }?.title ?? title)) {
            ForEach(pickerItems, id: \.id) { item in
                Text(item.title).tag(item.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(DesignSystem.Font.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignSystem.Spaces.one)
        .padding(.vertical, DesignSystem.Spaces.half)
        .modify { view in
            if #available(iOS 26.0, *) {
                view.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                view.clipShape(.capsule)
            }
        }
    }

    var descriptionContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Text(title)
                .font(.caption2.bold())
            Menu {
                ForEach(pickerItems, id: \.id) { item in
                    Button {
                        selectedItemId = item.id
                    } label: {
                        if item.id == selectedItemId {
                            Label(item.title, systemSymbol: .checkmark)
                        } else {
                            Text(item.title)
                        }
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
    ScrollView(.horizontal) {
        HStack {
            EntityFilterPickerView(
                title: "Filter 1",
                pickerItems: [.init(id: "1", title: "Abc"), .init(id: "2", title: "Def")],
                selectedItemId: .constant("1")
            )
            EntityFilterPickerView(
                title: "Filter 1",
                pickerItems: [.init(id: "1", title: "Abc"), .init(id: "2", title: "Def")],
                selectedItemId: .constant("1")
            )
        }
    }
}
