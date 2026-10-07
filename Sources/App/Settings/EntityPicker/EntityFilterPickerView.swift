import SFSafeSymbols
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
    let icon: SFSymbol?
    let pickerItems: [PickerItem]
    @Binding var selectedItemId: String?
    let style: Style

    init(
        title: String,
        icon: SFSymbol? = nil,
        pickerItems: [PickerItem],
        selectedItemId: Binding<String?>,
        style: Style = .compact
    ) {
        self.title = title
        self.icon = icon
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

    // A `Menu` is used instead of a `.menu`-styled `Picker` because the latter drops images from a
    // custom label, which would hide the filter icon.
    var compactContent: some View {
        Menu {
            ForEach(pickerItems, id: \.id) { item in
                Button {
                    selectedItemId = item.id.isEmpty ? nil : item.id
                } label: {
                    if item.id == (selectedItemId ?? "") {
                        Label(item.title, systemSymbol: .checkmark)
                    } else {
                        Text(item.title)
                    }
                }
            }
        } label: {
            compactLabel
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(DesignSystem.Font.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignSystem.Spaces.one)
        .padding(.vertical, DesignSystem.Spaces.half)
        .modify { view in
            if #available(iOS 26.0, *) {
                view
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .contentShape(Capsule())
            } else {
                view
                    .background(.tileBackground)
                    .clipShape(.capsule)
            }
        }
    }

    // Always shows the filter's icon (and, when nothing is selected, its title) so the capsule
    // communicates which dimension it filters even after a value is picked.
    @ViewBuilder
    private var compactLabel: some View {
        let selectedTitle = pickerItems.first { $0.id == selectedItemId }?.title
        HStack(spacing: DesignSystem.Spaces.half) {
            if let icon {
                Image(systemSymbol: icon)
            }
            Text(selectedTitle ?? title)
        }
    }

    var descriptionContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Label {
                Text(title)
            } icon: {
                if let icon {
                    Image(systemSymbol: icon)
                }
            }
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
                view
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .contentShape(Capsule())
            } else {
                view
                    .background(.tileBackground)
                    .clipShape(.capsule)
            }
        }
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack {
            EntityFilterPickerView(
                title: "Servers",
                icon: .serverRack,
                pickerItems: [.init(id: "1", title: "Home"), .init(id: "2", title: "Office")],
                selectedItemId: .constant("1")
            )
            EntityFilterPickerView(
                title: "Area",
                icon: .houseFill,
                pickerItems: [.init(id: "1", title: "Kitchen"), .init(id: "2", title: "Living room")],
                selectedItemId: .constant("1")
            )
        }
    }
}
