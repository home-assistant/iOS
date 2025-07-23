import SwiftUI
import Shared

struct BaseOnboardingTemplateView<Icon: View, Destination: View>: View {
    let icon: Icon
    let title: String
    let subtitle: String
    let bannerText: String?
    let primaryButtonTitle: String
    let primaryButtonAction: (() -> Void)?
    let primaryButtonDestination: Destination?
    let secondaryButtonTitle: String?
    let secondaryButtonAction: (() -> Void)?

    init(
        @ViewBuilder icon: () -> Icon,
        title: String,
        subtitle: String,
        bannerText: String? = nil,
        primaryButtonTitle: String,
        primaryButtonAction: (() -> Void)? = nil,
        @ViewBuilder primaryButtonDestination: () -> Destination? = { nil },
        secondaryButtonTitle: String? = nil,
        secondaryButtonAction: (() -> Void)? = nil
    ) {
        self.icon = icon()
        self.title = title
        self.subtitle = subtitle
        self.bannerText = bannerText
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryButtonAction = primaryButtonAction
        self.primaryButtonDestination = primaryButtonDestination()
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
                if let bannerText {
                    HABannerView(
                        icon: {
                            Image(.casita)
                        },
                        text: bannerText
                    )
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                if let primaryButtonDestination {
                    NavigationLink(destination: primaryButtonDestination) {
                        Text(primaryButtonTitle)
                    }
                    .buttonStyle(.primaryButton)
                } else if let primaryButtonAction {
                    Button(action: primaryButtonAction) {
                        Text(primaryButtonTitle)
                    }
                    .buttonStyle(.primaryButton)
                }
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
    BaseOnboardingTemplateView<Image, AnyView>(
        icon: { Image(systemName: "globe") },
        title: "Access outside your home",
        subtitle: "If you are interested in logging in to Home Assistant installation while away, you will have to make your instance remotely accessible. You can set this up in your Home Assistant instance.\n\nRight now, you can only connect while on your home network.",
        bannerText: "Your location will only be used to check if you are connected to your local network. It will not be shared with anyone.",
        primaryButtonTitle: "Skip for now",
        primaryButtonAction: {},
        secondaryButtonTitle: "I know my external URL",
        secondaryButtonAction: {}
    )
}
