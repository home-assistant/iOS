import Foundation
import Shared
import SwiftUI

struct OnboardingWelcomeView: View {
    @State private var showLearnMore = false

    @Binding var shouldDismissOnboarding: Bool

    var body: some View {
        VStack(spacing: .zero) {
            Spacer()
            Group {
                logoBlock
                textBlock
            }
            Spacer()
            continueButton
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .fullScreenCover(isPresented: $showLearnMore) {
            SafariWebView(url: AppConstants.WebURLs.homeAssistantGetStarted)
        }
    }

    private var logoBlock: some View {
        Image(uiImage: Asset.SharedAssets.logoHorizontalText.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 300)
            .padding(.vertical, Spaces.four)
    }

    private var textBlock: some View {
        ScrollView {
            VStack(spacing: Spaces.two) {
                Text(verbatim: L10n.Onboarding.Welcome.description)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            .padding()
        }
    }

    private var continueButton: some View {
        VStack {
            NavigationLink(destination: OnboardingServersListView(shouldDismissOnboarding: $shouldDismissOnboarding)) {
                Text(verbatim: L10n.continueLabel)
            }
            .buttonStyle(.primaryButton)
            .padding(.horizontal, Spaces.two)
            Button(L10n.Onboarding.Welcome.learnMore) {
                showLearnMore = true
            }
            .tint(Color.asset(Asset.Colors.haPrimary))
            .frame(minHeight: 40)
            .buttonStyle(.secondaryButton)
        }
    }
}

#Preview {
    OnboardingWelcomeView(shouldDismissOnboarding: .constant(false))
}
