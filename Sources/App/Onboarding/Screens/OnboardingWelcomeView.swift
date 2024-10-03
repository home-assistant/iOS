import Foundation
import Shared
import SwiftUI

struct OnboardingWelcomeView: View {
    @State private var showLearnMore = false

    var body: some View {
        VStack(spacing: .zero) {
            Spacer()
            logoBlock
            textBlock
            Spacer()
            continueButton
        }
        .frame(maxWidth: 600)
        .fullScreenCover(isPresented: $showLearnMore) {
            SafariWebView(url: URL(string: "http://www.home-assistant.io")!)
        }
    }

    private var logoBlock: some View {
        Image(uiImage: Asset.SharedAssets.logo.image)
            .padding(.vertical, Spaces.four)
    }

    private var textBlock: some View {
        ScrollView {
            VStack(spacing: Spaces.two) {
                Text(L10n.Onboarding.Welcome.title(Current.device.systemName()))
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                Text(L10n.Onboarding.Welcome.description)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Button(L10n.Onboarding.Welcome.learnMore) {
                    showLearnMore = true
                }
                .tint(Color.asset(Asset.Colors.haPrimary))
            }
            .padding()
        }
    }

    private var continueButton: some View {
        NavigationLink(destination: OnboardingScanningView()) {
            Text(L10n.continueLabel)
                .font(.callout.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(Color.asset(Asset.Colors.haPrimary))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }.padding(Spaces.two)
    }
}

#Preview {
    OnboardingWelcomeView()
}

struct OnboardingScanningView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        OnboardingScanningViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
