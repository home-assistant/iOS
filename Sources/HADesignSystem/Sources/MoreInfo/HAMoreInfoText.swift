#if !os(watchOS)
import HAIconic
import SwiftUI

/// The more-info dialog of an `input_text` or a `text`: the entity's row with a field holding its
/// value. The SwiftUI counterpart of the frontend's `state-card-input_text`, which `state-card-text`
/// shares; neither domain has a more-info control of its own.
public struct HAMoreInfoText: View {
    private let name: String
    private let icon: MaterialDesignIcons
    private let lastChanged: Date
    private let now: Date
    private let isPassword: Bool
    private let isUnavailable: Bool
    private let onSubmit: (() -> Void)?
    @Binding private var text: String

    /// - Parameters:
    ///   - isPassword: Hides what is typed, for an entity in `password` mode.
    ///   - onSubmit: Called when editing ends, which is when the frontend sends the new value.
    public init(
        name: String,
        icon: MaterialDesignIcons = .formTextboxIcon,
        lastChanged: Date,
        now: Date,
        text: Binding<String>,
        isPassword: Bool = false,
        isUnavailable: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.name = name
        self.icon = icon
        self.lastChanged = lastChanged
        self.now = now
        _text = text
        self.isPassword = isPassword
        self.isUnavailable = isUnavailable
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HAMoreInfoStateCard(name: name, icon: icon, lastChanged: lastChanged, now: now) {
            Group {
                if isPassword {
                    SecureField(name, text: $text)
                        .padding(DesignSystem.Spaces.two)
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf)
                                .stroke(.tileBorder, lineWidth: 1)
                        }
                } else {
                    HATextField(placeholder: name, text: $text)
                }
            }
            .frame(maxWidth: 180)
            .disabled(isUnavailable)
            .onSubmit { onSubmit?() }
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAMoreInfoText(
            name: "Text",
            lastChanged: Date(timeIntervalSinceNow: -60),
            now: Date(),
            text: .constant("Hello world")
        )
        HAMoreInfoText(
            name: "Password",
            lastChanged: Date(timeIntervalSinceNow: -600),
            now: Date(),
            text: .constant("secret"),
            isPassword: true
        )
    }
    .padding()
}

extension HAMoreInfoText: FrontendComponent {
    public static var frontendComponentName: String { "state-card-input_text" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
