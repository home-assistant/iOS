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
            .padding(Spaces.one)
            .padding(.horizontal)
            .background(selected ? Color.haPrimary : Color.secondary.opacity(0.1))
            .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        PillView(text: "Value1", selected: true)
        PillView(text: "Value2", selected: false)
        PillView(text: "Value3", selected: false)
    }
}
