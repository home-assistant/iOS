#if !os(watchOS)
import HAIconic
import SwiftUI

/// The more-info dialog of an `input_number` or a `number`: the entity's row with a slider and its
/// value, or a box to type the value into. The SwiftUI counterpart of the frontend's
/// `state-card-input_number`, which `state-card-number` shares; neither domain has a more-info
/// control of its own.
public struct HAMoreInfoNumber: View {
    /// The entity's `mode` attribute.
    public enum Mode: String, CaseIterable, Sendable {
        case slider
        case box
    }

    @Environment(\.locale) private var locale
    private let name: String
    private let icon: MaterialDesignIcons
    private let lastChanged: Date
    private let now: Date
    private let scale: HASliderScale
    private let unit: String?
    private let mode: Mode
    private let isUnavailable: Bool
    @Binding private var value: Double
    @State private var draft: String?
    @FocusState private var isEditing: Bool

    /// - Parameter value: Written once editing ends, when the box loses focus or is submitted, as
    ///   the frontend does; a half-typed number such as "-" is kept as typed until then.
    public init(
        name: String,
        icon: MaterialDesignIcons = .rayVertexIcon,
        lastChanged: Date,
        now: Date,
        value: Binding<Double>,
        scale: HASliderScale,
        unit: String? = nil,
        mode: Mode = .slider,
        isUnavailable: Bool = false
    ) {
        self.name = name
        self.icon = icon
        self.lastChanged = lastChanged
        self.now = now
        _value = value
        self.scale = scale
        self.unit = unit
        self.mode = mode
        self.isUnavailable = isUnavailable
    }

    private var fractionLength: Int {
        let step = scale.step.formatted(.number.locale(Locale(identifier: "en_US_POSIX")))
        return step.split(separator: ".").dropFirst().first?.count ?? 0
    }

    private var formattedValue: String {
        value.formatted(.number.precision(.fractionLength(fractionLength)).locale(locale))
    }

    private var text: Binding<String> {
        Binding(get: { draft ?? formattedValue }, set: { draft = $0 })
    }

    private func commit() {
        defer { draft = nil }
        guard let draft, let parsed = try? Double(draft, format: .number.locale(locale)) else { return }
        value = scale.bounded(parsed)
    }

    public var body: some View {
        HAMoreInfoStateCard(name: name, icon: icon, lastChanged: lastChanged, now: now) {
            switch mode {
            case .slider:
                HStack(spacing: DesignSystem.Spaces.one) {
                    Slider(value: $value, in: scale.min ... scale.max, step: scale.step)
                        .tint(.haPrimary)
                        .frame(minWidth: 100)
                        .accessibilityLabel(Text(name))
                    Text([formattedValue, unit].compactMap { $0 }.joined(separator: " "))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
                .disabled(isUnavailable)
            case .box:
                HStack(spacing: DesignSystem.Spaces.one) {
                    HATextField(placeholder: name, text: text, isFocused: $isEditing)
                        .keyboardType(.decimalPad)
                        .onSubmit { isEditing = false }
                        .onChange(of: isEditing) { editing in
                            if !editing {
                                commit()
                            }
                        }
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                    if let unit {
                        Text(unit)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isUnavailable)
            }
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAMoreInfoNumber(
            name: "Slider",
            lastChanged: Date(timeIntervalSinceNow: -360),
            now: Date(),
            value: .constant(40),
            scale: HASliderScale(min: 0, max: 100, step: 1),
            unit: "items"
        )
        HAMoreInfoNumber(
            name: "Box",
            lastChanged: Date(timeIntervalSinceNow: -1200),
            now: Date(),
            value: .constant(0),
            scale: HASliderScale(min: 0, max: 100, step: 0.5),
            unit: "items",
            mode: .box
        )
    }
    .padding()
}

extension HAMoreInfoNumber: FrontendComponent {
    public static var frontendComponentName: String { "state-card-input_number" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
