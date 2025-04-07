import Foundation
import Shared
import SwiftUI

struct OnboardingWelcomeView: View {
    @State private var showLearnMore = false
    @State private var showLogo = false
    @State private var showButtons = false
    @State private var logoScale = 0.9
    @State private var buttonYOffset: CGFloat = 10

    @Binding var shouldDismissOnboarding: Bool

    var body: some View {
        VStack(spacing: .zero) {
            Spacer()
            Group {
                logoBlock
                textBlock
            }
            .opacity(showLogo ? 1 : 0)
            .scaleEffect(logoScale)
            Spacer()
            continueButton
                .opacity(showButtons ? 1 : 0)
                .offset(y: buttonYOffset)
        }
        .frame(maxWidth: 600)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                showLogo = true
                logoScale = 1.0

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showButtons = true
                        buttonYOffset = 0
                    }
                }
            }
        }
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
            Button(L10n.Onboarding.Welcome.getStarted) {
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
