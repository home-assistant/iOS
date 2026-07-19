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

/// Hosts the onboarding screens. Navigation between them is done by swapping content in place rather
/// than pushing — removing this view (when onboarding completes) while a page is pushed leaks the
/// pushed page's hosting view over the app.
struct OnboardingNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection
    @StateObject public var viewModel = OnboardingNavigationViewModel()
    public let onboardingStyle: OnboardingStyle

    @State private var showsServersList = false

    init(onboardingStyle: OnboardingStyle) {
        self.onboardingStyle = onboardingStyle
    }

    var body: some View {
        NavigationView {
            Group {
                switch onboardingStyle {
                case .initial, .required:
                    welcomeFlow
                case .secondary:
                    OnboardingServersListView(onboardingStyle: onboardingStyle)
                        .navigationTitle(L10n.Settings.ConnectionSection.addServer)
                }
            }
            .navigationViewStyle(.stack)
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
        .navigationViewStyle(.stack)
        .onChange(of: viewModel.shouldDismiss) { newValue in
            if newValue {
                closeOnboarding()
            }
        }
    }

    /// Welcome ↔ servers list, swapped in place with a push-like slide.
    @ViewBuilder
    private var welcomeFlow: some View {
        ZStack {
            if showsServersList {
                OnboardingServersListView(
                    onboardingStyle: onboardingStyle,
                    backAction: { showsServersList = false }
                )
                .transition(.move(edge: trailingEdge))
            } else {
                OnboardingWelcomeView(continueAction: { showsServersList = true })
                    .transition(.move(edge: leadingEdge))
            }
        }
        .animation(DesignSystem.Animation.default, value: showsServersList)
    }

    private var leadingEdge: Edge {
        layoutDirection == .leftToRight ? .leading : .trailing
    }

    private var trailingEdge: Edge {
        layoutDirection == .leftToRight ? .trailing : .leading
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
