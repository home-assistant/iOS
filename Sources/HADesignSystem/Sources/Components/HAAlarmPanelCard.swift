#if !os(watchOS)
import SwiftUI

/// An alarm panel: the current state, the arming modes, and a keypad. The SwiftUI counterpart of the
/// frontend's `hui-alarm-panel-card`.
public struct HAAlarmPanelCard: View {
    private let name: String
    private let state: String
    private let stateColor: Color
    private let modes: [HAControlSelectOption]
    private let showsKeypad: Bool
    @Binding private var code: String
    private let onMode: (HAControlSelectOption) -> Void

    /// - Parameters:
    ///   - modes: The arming options offered, e.g. Home and Away. The frontend's `states`.
    ///   - showsKeypad: The frontend shows it when the alarm reports `code_format: number`.
    public init(
        name: String,
        state: String,
        stateColor: Color = .haSuccessColor,
        modes: [HAControlSelectOption],
        code: Binding<String> = .constant(""),
        showsKeypad: Bool = false,
        onMode: @escaping (HAControlSelectOption) -> Void
    ) {
        self.name = name
        self.state = state
        self.stateColor = stateColor
        self.modes = modes
        _code = code
        self.showsKeypad = showsKeypad
        self.onMode = onMode
    }

    /// Three columns of digits with a zero centred under them, as a phone keypad is.
    /// The trailing slot is a delete key, as the frontend's keypad has: every other key only
    /// appends, so without it a mistyped digit can only be undone by abandoning the card.
    private static let deleteKey = "\u{232B}"
    private static let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", deleteKey]

    public var body: some View {
        HACard {
            VStack(spacing: DesignSystem.Spaces.two) {
                VStack(spacing: DesignSystem.Spaces.micro) {
                    Text(name)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                    Text(state)
                        .font(DesignSystem.Font.title2)
                        .foregroundStyle(stateColor)
                }
                HStack(spacing: DesignSystem.Spaces.one) {
                    ForEach(modes) { mode in
                        Button(mode.label) { onMode(mode) }
                            .buttonStyle(.outlinedButton)
                    }
                }
                if showsKeypad {
                    Text(String(repeating: "•", count: code.count))
                        .font(DesignSystem.Font.title3)
                        .frame(height: 28)
                        .accessibilityLabel(Text("\(code.count)"))
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 3),
                        spacing: DesignSystem.Spaces.one
                    ) {
                        ForEach(Array(Self.keys.enumerated()), id: \.offset) { _, key in
                            // The blank left of the zero keeps it centred without a bespoke layout;
                            // it is a spacer, not a button.
                            if key.isEmpty {
                                Color.clear.frame(height: 44)
                            } else if key == Self.deleteKey {
                                Button(key) { _ = code.popLast() }
                                    .buttonStyle(.neutralButton)
                                    .disabled(code.isEmpty)
                                    .accessibilityLabel(
                                        Text(HADesignSystemEnvironment.current.strings.deleteDigit)
                                    )
                            } else {
                                Button(key) { code += key }
                                    .buttonStyle(.neutralButton)
                            }
                        }
                    }
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAAlarmPanelCard(
            name: "Alarm",
            state: "Disarmed",
            modes: [.init(id: "home", label: "Home"), .init(id: "away", label: "Away")],
            onMode: { _ in }
        )
        HAAlarmPanelCard(
            name: "Alarm",
            state: "Armed away",
            stateColor: .haErrorColor,
            modes: [.init(id: "disarm", label: "Disarm")],
            code: .constant("123"),
            showsKeypad: true,
            onMode: { _ in }
        )
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAAlarmPanelCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-alarm-panel-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
