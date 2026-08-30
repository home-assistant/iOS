#if !os(watchOS)
import SwiftUI

/// A list of entities on a card, each an ``HAEntityRow``. The SwiftUI counterpart of the frontend's
/// `hui-entities-card`.
///
/// The header can carry a toggle that acts on everything listed — the frontend's `show_header_toggle`
/// — which is why the title is not simply `HACard`'s.
public struct HAEntitiesCard<Content: View>: View {
    private let title: String?
    private let headerToggle: Binding<Bool>?
    private let content: Content

    /// - Parameter headerToggle: Pass a binding to put a toggle beside the title. The caller decides
    ///   what it means for the group, as the frontend leaves that to the card's config.
    public init(
        title: String? = nil,
        headerToggle: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.headerToggle = headerToggle
        self.content = content()
    }

    public var body: some View {
        HACard {
            VStack(spacing: .zero) {
                if title != nil || headerToggle != nil {
                    HStack {
                        if let title {
                            Text(title)
                                .font(DesignSystem.Font.title2)
                        }
                        Spacer(minLength: DesignSystem.Spaces.one)
                        if let headerToggle {
                            // Labelled with the card's title even though the label is hidden:
                            // `labelsHidden` only stops it being drawn, and an empty string would
                            // leave VoiceOver with an unnamed switch.
                            Toggle(title ?? "", isOn: headerToggle)
                                .labelsHidden()
                                .accessibilityLabel(optional: title)
                        }
                    }
                    .padding(.bottom, DesignSystem.Spaces.one)
                }
                content
            }
            .padding(DesignSystem.Spaces.two)
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAEntitiesCard(title: "Living room") {
            HAEntityRow(name: "Paulus", icon: .accountIcon, color: .haSuccessColor, state: "Home")
            HAEntityRow(name: "Humidity", icon: .waterPercentIcon, state: "23.2 %")
            HAEntityRow(name: "Bed Light", icon: .lightbulbIcon, color: .haWarningColor) {
                Toggle("", isOn: .constant(true)).labelsHidden()
            }
        }
        HAEntitiesCard(title: "Random group", headerToggle: .constant(true)) {
            HAEntityRow(name: "Romantic Scene", icon: .paletteIcon, actionTitle: "Activate") {}
            HAEntityRow(name: "Paulus", icon: .accountIcon, color: .haSuccessColor, state: "Home")
        }
        HAEntitiesCard {
            HAEntityRow(name: "No title", icon: .homeOutlineIcon, state: "On")
        }
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAEntitiesCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-entities-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
