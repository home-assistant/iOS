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

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showLearnMore = false
    /// Advances to the servers list; the onboarding container swaps content in place (no navigation
    /// push — tearing the container down with a pushed page leaks its hosting view).
    let continueAction: () -> Void

    /// In a short window (closed iPhone Duo or any iPhone in landscape) the bottom buttons would
    /// cover most of the content, so the actions move into the navigation bar instead.
    private var showsActionsInToolbar: Bool {
        verticalSizeClass == .compact
    }

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
            if !showsActionsInToolbar {
                continueButtonBlock
            }
        })
        .toolbar {
            if showsActionsInToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Onboarding.Welcome.Updated.secondaryButton) {
                        showLearnMore = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Onboarding.Welcome.primaryButtonCompact, action: continueAction)
                        .fontWeight(.semibold)
                        .tint(Color.haPrimary)
                        .accessibilityIdentifier(AccessibilityIdentifier.onboardingWelcomeContinue.rawValue)
                }
            }
        }
        // Centers the content on the full display width when a horizontal safe area inset is
        // present (e.g. iPhone Duo camera or vertical bar) instead of on the inset region.
        .ignoresSafeArea(.container, edges: .horizontal)
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
                .launchSplashLogoAnchor()
            Text(verbatim: L10n.Onboarding.Welcome.header)
                .font(DesignSystem.Font.largeTitle.bold())
                .padding(.horizontal, DesignSystem.Spaces.two)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
            Button(action: continueAction) {
                Text(verbatim: L10n.Onboarding.Welcome.primaryButton)
            }
            .buttonStyle(.primaryButton)
            .accessibilityIdentifier(AccessibilityIdentifier.onboardingWelcomeContinue.rawValue)
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
    NavigationStack {
        OnboardingWelcomeView(continueAction: {})
    }
}
