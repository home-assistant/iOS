import SwiftUI
import Shared

struct BaseOnboardingTemplateView<Icon: View>: View {
    let icon: Icon
    let title: String
    let subtitle: String
    let primaryButtonTitle: String
    let primaryButtonAction: () -> Void
    let secondaryButtonTitle: String?
    let secondaryButtonAction: (() -> Void)?

    init(
        @ViewBuilder icon: () -> Icon,
        title: String,
        subtitle: String,
        primaryButtonTitle: String,
        primaryButtonAction: @escaping () -> Void,
        secondaryButtonTitle: String? = nil,
        secondaryButtonAction: (() -> Void)? = nil
    ) {
        self.icon = icon()
        self.title = title
        self.subtitle = subtitle
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryButtonAction = primaryButtonAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryButtonAction = secondaryButtonAction
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.three) {
                if let icon = icon as? Image {
                    icon
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: OnboardingConstants.iconSize)
                        .foregroundStyle(.haPrimary)
                }
                Text(title)
                    .font(DesignSystem.Font.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(DesignSystem.Spaces.two)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                Button(action: primaryButtonAction) {
                    Text(primaryButtonTitle)
                }
                .buttonStyle(.primaryButton)
                if let secondaryTitle = secondaryButtonTitle, let secondaryAction = secondaryButtonAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                    }
                    .buttonStyle(.secondaryButton)
                }
            }
            .padding([.horizontal, .top], DesignSystem.Spaces.two)
        }
    }
}

#Preview {
    BaseOnboardingTemplateView(
        icon: { Image(systemName: "globe") },
        title: "Access outside your home",
        subtitle: "If you are interested in logging in to Home Assistant installation while away, you will have to make your instance remotely accessible. You can set this up in your Home Assistant instance.\n\nRight now, you can only connect while on your home network.",
        primaryButtonTitle: "Skip for now",
        primaryButtonAction: {},
        secondaryButtonTitle: "I know my external URL",
        secondaryButtonAction: {}
    )
}
