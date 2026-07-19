import SFSafeSymbols
import Shared
import SwiftUI
import WebKit

/// The Home Assistant login page for onboarding and re-authentication. Pushed onto the onboarding
/// navigation stack (`.pushed`, back button cancels) or presented modally with its own navigation bar
/// and cancel button (`.modal`, used by re-authentication flows).
struct OnboardingAuthLoginView: View {
    enum Style {
        case pushed
        case modal
    }

    @ObservedObject var viewModel: OnboardingAuthLoginViewModel
    var style: Style = .pushed

    var body: some View {
        switch style {
        case .pushed:
            // Cancellation comes from the navigation back button; disappearing while the OAuth
            // callback is unresolved rejects the login promise.
            content
        case .modal:
            NavigationView {
                content
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.cancelLabel) {
                                viewModel.cancel()
                            }
                        }
                    }
            }
            .navigationViewStyle(.stack)
            .interactiveDismissDisabled()
        }
    }

    private var content: some View {
        LoginWebView(webView: viewModel.webView)
            .overlay {
                // Shown while the login page loads, and after the OAuth callback while the rest of
                // the auth flow (token exchange, registration) runs before the next screen replaces us.
                if viewModel.isLoading || viewModel.didCompleteLogin {
                    ZStack {
                        Color(uiColor: .systemBackground)
                            .opacity(0.8)
                            .ignoresSafeArea()
                        HAProgressView()
                    }
                }
            }
            .navigationTitle(viewModel.authDetails.url.host ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemSymbol: .arrowClockwise)
                    }
                }
            }
            .onAppear {
                viewModel.startIfNeeded()
            }
            .onDisappear {
                viewModel.cancelIfUnresolved()
            }
    }

    /// Hosts the view model's `WKWebView`; all WebKit behavior lives on the view model.
    private struct LoginWebView: UIViewRepresentable {
        let webView: WKWebView

        func makeUIView(context: Context) -> WKWebView {
            webView
        }

        func updateUIView(_ uiView: WKWebView, context: Context) {}
    }
}

#Preview {
    NavigationStack {
        OnboardingAuthLoginView(
            // swiftlint:disable:next force_try
            viewModel: OnboardingAuthLoginViewModel(authDetails: try! OnboardingAuthDetails(
                baseURL: URL(string: "http://homeassistant.local:8123")!
            ))
        )
    }
}
