#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// A set of radio cards, each with a label and optionally a description and a picture. The SwiftUI
/// counterpart of the frontend's `ha-select-box`.
///
/// Used where a plain picker would hide the differences between the choices — onboarding steps and
/// setup flows, where each option needs a sentence explaining it.
public struct HASelectBox: View {
    private let options: [HASelectBoxOption]
    private let maxColumns: Int
    private let isDisabled: Bool
    @Binding private var selection: String?

    /// - Parameter maxColumns: Above one, the cards lay out in a grid rather than a list. The
    ///   frontend's `max_columns`.
    public init(
        options: [HASelectBoxOption],
        selection: Binding<String?>,
        maxColumns: Int = 1,
        isDisabled: Bool = false
    ) {
        self.options = options
        _selection = selection
        self.maxColumns = maxColumns
        self.isDisabled = isDisabled
    }

    public var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: DesignSystem.Spaces.one),
                count: Swift.max(1, maxColumns)
            ),
            spacing: DesignSystem.Spaces.one
        ) {
            ForEach(options) { option in
                let isSelected = selection == option.id
                Button {
                    selection = option.id
                } label: {
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: isSelected ? .largecircleFillCircle : .circle)
                            .foregroundStyle(isSelected ? Color.haPrimary : .secondary)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                            if let image = option.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 40)
                            }
                            Text(option.label)
                                .font(DesignSystem.Font.body)
                            if let description = option.description {
                                Text(description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: .zero)
                    }
                    .padding(DesignSystem.Spaces.oneAndHalf)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isSelected ? Color.haPrimary.opacity(0.08) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: HACornerRadius.standard)
                            .strokeBorder(
                                isSelected ? Color.haPrimary : Color.haDivider,
                                lineWidth: DesignSystem.Border.Width.default
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: HACornerRadius.standard))
                }
                .buttonStyle(.plain)
                .disabled(option.isDisabled)
                .opacity(option.isDisabled ? 0.5 : 1)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HASelectBox(
            options: [
                .init(
                    id: "cloud",
                    label: "Home Assistant Cloud",
                    description: "The easiest way to connect from anywhere."
                ),
                .init(id: "manual", label: "Manual", description: "Enter the address of your instance yourself."),
            ],
            selection: .constant("cloud")
        )
        HASelectBox(
            options: [
                .init(id: "a", label: "One"),
                .init(id: "b", label: "Two"),
                .init(id: "c", label: "Three", isDisabled: true),
            ],
            selection: .constant("b"),
            maxColumns: 3
        )
    }
    .padding()
}

extension HASelectBox: FrontendComponent {
    public static var frontendComponentName: String { "ha-select-box" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
