import SFSafeSymbols
import SwiftUI

/// A single-line text field with a clear button.
///
/// Frontend counterpart: `ha-textfield` and its outlined variant `ha-outlined-field`, both of which
/// wrap a Material text field. This draws the outlined one.
public struct HATextField: View {
    let placeholder: String
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding?

    /// - Parameter isFocused: Tracks whether the field is being edited, for a caller that commits
    ///   the value when editing ends.
    public init(placeholder: String, text: Binding<String>, isFocused: FocusState<Bool>.Binding? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.isFocused = isFocused
    }

    public var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .modify { field in
                    if let isFocused {
                        field.focused(isFocused)
                    }
                }
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

extension HATextField: FrontendComponent {
    public static var frontendComponentName: String { "ha-textfield" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}
