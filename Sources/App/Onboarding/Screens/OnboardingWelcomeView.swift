import Foundation
import Shared
import SwiftUI

private enum OnboardingWelcomeConstants {
    static let logoWidth: CGFloat = 147
    static let logoHeight: CGFloat = 174
    static let logoOffsetDelay: Double = 0.3
    static let logoAnimationDuration: Double = 0.5
    static let textBlockDelay: Double = 0.9
    static let textBlockAnimationDuration: Double = 0.5
    static let textBlockYOffset: CGFloat = 320
    static let logoMaxWidth: CGFloat = 300
    static let logoVerticalPadding: CGFloat = Spaces.four
    static let continueButtonHorizontalPadding: CGFloat = Spaces.two
    static let continueButtonMinHeight: CGFloat = 40
}

struct OnboardingWelcomeView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @State private var showLearnMore = false
    @State private var animateLogo = false
    @State private var showText = false
    @Binding var shouldDismissOnboarding: Bool

    var body: some View {
        ZStack(alignment: animateLogo ? .top : .center) {
            logoBlock
                .offset(x: 0, y: animateLogo ? safeAreaInsets.top + Spaces.five : 0)
            textBlock
                .offset(x: 0, y: OnboardingWelcomeConstants.textBlockYOffset)
                .opacity(showText ? 1 : 0)
            VStack {
                Spacer()
                continueButtonBlock
                    .padding(.bottom, safeAreaInsets.bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .ignoresSafeArea()
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingWelcomeConstants.logoOffsetDelay) {
                withAnimation(.easeInOut(duration: OnboardingWelcomeConstants.logoAnimationDuration)) {
                    animateLogo = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingWelcomeConstants.textBlockDelay) {
                withAnimation(.easeInOut(duration: OnboardingWelcomeConstants.textBlockAnimationDuration)) {
                    showText = true
                }
            }
        }
        .fullScreenCover(isPresented: $showLearnMore) {
            SafariWebView(url: AppConstants.WebURLs.homeAssistantGetStarted)
        }
    }

    private var logoBlock: some View {
        Image(.launchScreenLogo)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(
                width: OnboardingWelcomeConstants.logoWidth,
                height: OnboardingWelcomeConstants.logoHeight,
                alignment: .center
            )
    }

    private var textBlock: some View {
        ScrollView {
            VStack(alignment: .center, spacing: Spaces.two) {
                Text(verbatim: L10n.Onboarding.Welcome.description)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private var continueButtonBlock: some View {
        VStack {
            NavigationLink(destination: OnboardingServersListView()) {
                Text(verbatim: L10n.Onboarding.Welcome.continueButton)
            }
            .buttonStyle(.primaryButton)
            .padding(.horizontal, OnboardingWelcomeConstants.continueButtonHorizontalPadding)
            Button(L10n.Onboarding.Welcome.secondaryButton) {
                showLearnMore = true
            }
            .tint(Color.haPrimary)
            .frame(minHeight: OnboardingWelcomeConstants.continueButtonMinHeight)
            .buttonStyle(.secondaryButton)
        }
        .opacity(showText ? 1 : 0)
    }
}

#Preview {
    OnboardingWelcomeView(shouldDismissOnboarding: .constant(false))
}
