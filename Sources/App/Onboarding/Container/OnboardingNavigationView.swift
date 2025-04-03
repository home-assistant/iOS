import Shared
import SwiftUI

struct OnboardingNavigationView: View {
    static func controller(onboardingStyle: OnboardingStyle) -> UIViewController {
        OnboardingNavigationView(onboardingStyle: onboardingStyle).embeddedInHostingController()
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject public var viewModel = OnboardingNavigationViewModel()
    public let onboardingStyle: OnboardingStyle

    init(onboardingStyle: OnboardingStyle) {
        self.onboardingStyle = onboardingStyle
    }

    var body: some View {
        NavigationView {
            Group {
                switch onboardingStyle {
                case .initial:
                    OnboardingWelcomeView(shouldDismissOnboarding: $viewModel.shouldDismiss)
                case .secondary:
                    OnboardingServersListView(shouldDismissOnboarding: $viewModel.shouldDismiss)
                case let .required(type):
                    switch type {
                    case .full:
                        OnboardingWelcomeView(shouldDismissOnboarding: $viewModel.shouldDismiss)
                    case .permissions:
                        OnboardingPermissionsNavigationView()
                    }
                }
            }
            .navigationViewStyle(.stack)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if onboardingStyle.insertsCancelButton {
                        Button(action: {
                            closeOnboarding()
                        }) {
                            Text(L10n.cancelLabel)
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.shouldDismiss) { newValue in
            if newValue {
                closeOnboarding()
            }
        }
    }

    private func closeOnboarding() {
        if onboardingStyle == .secondary {
            dismiss()
        } else {
            Current.sceneManager.webViewWindowControllerPromise.done { windowController in
                windowController.setup()
            }
        }
    }
}
