import Shared
import SwiftUI

enum OnboardingStyle: Hashable {
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
        NavigationStack {
            Group {
                switch onboardingStyle {
                case .initial:
                    OnboardingWelcomeView(shouldDismissOnboarding: $viewModel.shouldDismiss)
                case .secondary:
                    OnboardingServersListView(onboardingStyle: onboardingStyle)
                        .navigationTitle(L10n.Settings.ConnectionSection.addServer)
                case .required:
                    OnboardingWelcomeView(shouldDismissOnboarding: $viewModel.shouldDismiss)
                }
            }
            .navigationDestination(for: OnboardingRoute.self) { route in
                destination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if onboardingStyle.insertsCancelButton, !Current.isCatalyst {
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

    /// Pushed pages keep their own `ViewControllerProvider` injection so presenting UIKit modals
    /// (e.g. the auth flow) does not depend on environment propagation from the stack root.
    @ViewBuilder
    private func destination(for route: OnboardingRoute) -> some View {
        switch route {
        case let .serversList(style):
            OnboardingServersListView(onboardingStyle: style)
                .injectingViewControllerProvider()
        }
    }

    private func closeOnboarding() {
        if onboardingStyle == .secondary {
            dismiss()
        } else {
            Current.sceneManager.appCoordinator.done { coordinator in
                coordinator.setup()
            }
        }
    }
}
