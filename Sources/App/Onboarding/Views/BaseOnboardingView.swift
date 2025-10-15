import Shared
import SwiftUI

/// A reusable screen scaffold for onboarding-style pages:
/// - Illustration at the top
/// - Big, centered title
/// - One or two body paragraphs
/// - Optional developer-injected content below the description
/// - Optional list of selectable choices (radio-style)
/// - Optional informational callout below choices
/// - Bottom area with primary button and optional secondary button
public struct BaseOnboardingView<Illustration: View, Content: View>: View {
    // MARK: - Inputs

    private let illustration: () -> Illustration
    private let title: String
    private let primaryDescription: String
    private let secondaryDescription: String?

    // Optional injected content placed below the secondary description
    private let content: (() -> Content)?

    private let primaryActionTitle: String
    private let primaryAction: () -> Void

    private let secondaryActionTitle: String?
    private let secondaryAction: (() -> Void)?

    // Layout tuning
    private let verticalSpacing: CGFloat
    private let maxContentWidth: CGFloat = Sizes.maxWidthForLargerScreens

    // MARK: - Inits

    /// Iinitializer that accepts custom content below the descriptions.
    public init(
        @ViewBuilder illustration: @escaping () -> Illustration,
        title: String,
        primaryDescription: String,
        secondaryDescription: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        primaryActionTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        illustrationTopPadding: CGFloat = DesignSystem.Spaces.four,
        verticalSpacing: CGFloat = DesignSystem.Spaces.three
    ) {
        self.illustration = illustration
        self.title = title
        self.primaryDescription = primaryDescription
        self.secondaryDescription = secondaryDescription
        self.content = content
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.verticalSpacing = verticalSpacing
    }

    /// No custom content initializer.
    public init(
        @ViewBuilder illustration: @escaping () -> Illustration,
        title: String,
        primaryDescription: String,
        secondaryDescription: String? = nil,
        primaryActionTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        illustrationTopPadding: CGFloat = DesignSystem.Spaces.four,
        verticalSpacing: CGFloat = DesignSystem.Spaces.three
    ) where Content == EmptyView {
        self.illustration = illustration
        self.title = title
        self.primaryDescription = primaryDescription
        self.secondaryDescription = secondaryDescription
        self.content = nil
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.verticalSpacing = verticalSpacing
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: verticalSpacing) {
                Group {
                    if let image = illustration() as? Image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 130)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        illustration()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.top, DesignSystem.Spaces.two)

                Text(title)
                    .font(DesignSystem.Font.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spaces.two)

                VStack(spacing: DesignSystem.Spaces.two) {
                    Text(primaryDescription)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let secondaryDescription {
                        Text(secondaryDescription)
                            .font(DesignSystem.Font.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let content {
                        content()
                    }
                }
                .padding(.horizontal, DesignSystem.Spaces.two)

                Spacer(minLength: DesignSystem.Spaces.four)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: maxContentWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Bottom actions

    @ViewBuilder
    private var bottomActions: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Button(action: primaryAction) {
                Text(primaryActionTitle)
            }
            .buttonStyle(.primaryButton)

            if let secondaryActionTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryActionTitle)
                }
                .buttonStyle(.secondaryButton)
                .tint(Color.haPrimary)
            }
        }
        .padding(.bottom, Current.isCatalyst ? DesignSystem.Spaces.two : .zero)
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding([.horizontal, .top], DesignSystem.Spaces.two)
        .background(Color(uiColor: .systemBackground).opacity(0.95))
    }
}

// MARK: - Previews

#Preview("Location permission example (simple)") {
    NavigationView {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.world)
            },
            title: "Use this device's location for automations",
            primaryDescription: "Location sharing enables powerful automations, such as turning off the heating when you leave home. This option shares the device’s location only with your Home Assistant system.",
            secondaryDescription: "This data stays in your home and is never sent to third parties. It also helps strengthen the security of your connection to Home Assistant.",
            primaryActionTitle: "Share my location",
            primaryAction: {},
            secondaryActionTitle: "Do not share my location",
            secondaryAction: {}
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("With injected content") {
    NavigationView {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.world)
            },
            title: "Use this device's location for automations",
            primaryDescription: "Location sharing enables powerful automations.",
            secondaryDescription: "This data stays in your home and is never sent to third parties.",
            content: {
                VStack(spacing: DesignSystem.Spaces.one) {
                    Toggle(isOn: .constant(true)) {
                        Text("Also share precise location")
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("You can change this later in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: DesignSystem.List.rowMaxWidth)
            },
            primaryActionTitle: "Share my location",
            primaryAction: {},
            secondaryActionTitle: "Do not share my location",
            secondaryAction: {}
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
