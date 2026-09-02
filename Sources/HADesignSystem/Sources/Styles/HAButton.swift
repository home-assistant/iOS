import SwiftUI

/// A filled, brand-coloured button style.
///
/// Frontend counterpart: `ha-button` in its default (filled) variant. The fuller set of variants —
/// outlined, neutral, negative, critical, plain — is in ``HAButtonStyle`` alongside; this one
/// predates it and is what the app's existing screens use.
public struct TextButton: ButtonStyle {
    private let backgroundColor = Color.haPrimary

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: 40)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .foregroundColor(Color.haPrimary)
            .background(configuration.isPressed ? backgroundColor.opacity(0.08) : backgroundColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: .infinity))
    }
}

public extension ButtonStyle where Self == TextButton {
    static var textButton: some ButtonStyle {
        TextButton()
    }
}

#Preview {
    Button(action: {}) {
        Text("Hello World")
    }
    .buttonStyle(.textButton)
}

extension TextButton: FrontendComponent {
    public static var frontendComponentName: String { "ha-button" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}
