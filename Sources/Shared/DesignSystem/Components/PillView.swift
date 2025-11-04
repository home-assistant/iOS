import SwiftUI

public struct PillView: View {
    private let selected: Bool
    private let text: String

    public init(text: String, selected: Bool) {
        self.text = text
        self.selected = selected
    }

    public var body: some View {
        Text(text)
            .foregroundStyle(selected ? .white : Color(uiColor: .label))
            .padding(DesignSystem.Spaces.one)
            .padding(.horizontal)
            .modify { view in
                if #available(iOS 26.0, *) {
                    view
                        .glassEffect(.clear.interactive().tint(selected ? Color.haPrimary : nil), in: .capsule)
                } else {
                    view
                        .background(selected ? Color.haPrimary : Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack {
            PillView(text: "Value1", selected: true)
            PillView(text: "Value2", selected: false)
            PillView(text: "Value3", selected: false)
            PillView(text: "Value4", selected: false)
            PillView(text: "Value5", selected: false)
            PillView(text: "Value6", selected: false)
        }
    }
}
