import SFSafeSymbols
import SwiftUI

public struct HATextField: View {
    let placeholder: String
    let keyboardType: UIKeyboardType
    @Binding var text: String

    public init(placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) {
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self._text = text
    }

    public var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
            Button(action: {
                text = ""
            }, label: {
                Image(systemSymbol: .xmark)
                    .foregroundStyle(.gray)
            })
            .buttonStyle(.plain)
            .opacity(text.isEmpty ? 0 : 1)
            .animation(.easeInOut, value: text)
        }
        .padding(DesignSystem.Spaces.two)
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf)
                .stroke(.tileBorder, lineWidth: 1)
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HATextField(placeholder: "Placeholder", text: .constant(""))
        HATextField(placeholder: "Placeholder", text: .constant("123"))
        HATextField(placeholder: "Placeholder", text: .constant("https://bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.com"))
    }
    .padding()
}
