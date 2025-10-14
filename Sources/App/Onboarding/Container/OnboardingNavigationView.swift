import Shared
import SwiftUI

enum OnboardingStyle: Equatable {
    case initial
    case required
    case secondary

    var insertsCancelButton: Bool {
        switch self {
        case .initial, .required: return false
        case .secondary: return true
        }
    }
}

enum OnboardingNavigation {
    public static var requiredOnboardingStyle: OnboardingStyle? {
        if Current.servers.all.isEmpty {
            return .required
        } else {
            return nil
        }
    }
}

struct OnboardingNavigationView: View {
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
                    OnboardingServersListView()
                case .required:
                    OnboardingWelcomeView(shouldDismissOnboarding: $viewModel.shouldDismiss)
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
        .navigationViewStyle(.stack)
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
