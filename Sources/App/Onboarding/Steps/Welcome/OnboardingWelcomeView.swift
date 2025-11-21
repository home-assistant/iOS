import Foundation
import Shared
import SwiftUI

struct OnboardingWelcomeView: View {
    private enum Constants {
        static let distanceToTop: CGFloat = 50
        static let logoWidth: CGFloat = 120
        static let logoHeight: CGFloat = 120
        static let distanceBetweenLogoAndTitle: CGFloat = 46
    }

    @State private var showLearnMore = false
    @Binding var shouldDismissOnboarding: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.three) {
                Spacer()
                logoBlock
                textBlock
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .frame(maxWidth: Sizes.maxWidthForLargerScreens)
            .padding(.top, Constants.distanceToTop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, content: {
            continueButtonBlock
        })
        .sheet(isPresented: $showLearnMore) {
            SafariWebView(url: AppConstants.WebURLs.homeAssistantCompanionGetStarted)
        }
    }

    private var logoBlock: some View {
        VStack(spacing: Constants.distanceBetweenLogoAndTitle) {
            Image(.logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .accessibilityLabel(L10n.Onboarding.Welcome.Logo.accessibilityLabel)
                .frame(
                    width: Constants.logoWidth,
                    height: Constants.logoHeight,
                    alignment: .center
                )
            Text(verbatim: L10n.Onboarding.Welcome.header)
                .font(DesignSystem.Font.largeTitle.bold())
                .padding(.horizontal, DesignSystem.Spaces.two)
        }
    }

    private var textBlock: some View {
        VStack(alignment: .center, spacing: DesignSystem.Spaces.two) {
            Text(verbatim: L10n.Onboarding.Welcome.Updated.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var continueButtonBlock: some View {
        VStack {
            NavigationLink(destination: OnboardingServersListView(onboardingStyle: .initial)) {
                Text(verbatim: L10n.Onboarding.Welcome.primaryButton)
            }
            .buttonStyle(.primaryButton)
            Button(L10n.Onboarding.Welcome.Updated.secondaryButton) {
                showLearnMore = true
            }
            .tint(Color.haPrimary)
            .buttonStyle(.secondaryButton)
        }
        .padding([.horizontal, .top], DesignSystem.Spaces.two)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    NavigationView {
        if #available(iOS 18.0, *) {
            OnboardingWelcomeView(shouldDismissOnboarding: .constant(false))
                .toolbarVisibility(.hidden, for: .navigationBar)
        } else {
            OnboardingWelcomeView(shouldDismissOnboarding: .constant(false))
        }
    }
}
