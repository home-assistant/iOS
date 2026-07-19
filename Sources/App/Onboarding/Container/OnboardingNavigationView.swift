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

/// Hosts the onboarding screens in a `NavigationStack` whose path is owned by the
/// `OnboardingAuthPresenter`, so the auth flow's steps (login web view, device naming, permissions)
/// are real pushes.
struct OnboardingNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject public var viewModel = OnboardingNavigationViewModel()
    @StateObject private var presenter = OnboardingAuthPresenter()

    public let onboardingStyle: OnboardingStyle
    private let prefillURL: URL?
    private let shouldDismissOnSuccess: Bool

    init(onboardingStyle: OnboardingStyle, prefillURL: URL? = nil, shouldDismissOnSuccess: Bool = false) {
        self.onboardingStyle = onboardingStyle
        self.prefillURL = prefillURL
        self.shouldDismissOnSuccess = shouldDismissOnSuccess
    }

    var body: some View {
        NavigationStack(path: $presenter.path) {
            root
                .navigationDestination(for: OnboardingDestination.self) { destination in
                    view(for: destination)
                }
        }
        .alert(
            L10n.Onboarding.ConnectionTestResult.CertificateError.title,
            isPresented: certificateTrustAlertBinding,
            presenting: presenter.certificateTrustRequest
        ) { request in
            Button(L10n.Onboarding.ConnectionTestResult.CertificateError.actionTrust, role: .destructive) {
                request.trust()
            }
            Button(L10n.Onboarding.ConnectionTestResult.CertificateError.actionDontTrust, role: .cancel) {
                request.dontTrust()
            }
        } message: { request in
            Text(request.message)
        }
        .sheet(item: $presenter.clientCertificateRequest) { request in
            clientCertificateSheet(request: request)
        }
        .onChange(of: viewModel.shouldDismiss) { newValue in
            if newValue {
                closeOnboarding()
            }
        }
    }

    @ViewBuilder
    private var root: some View {
        switch onboardingStyle {
        case .initial, .required:
            OnboardingWelcomeView(continueAction: { presenter.push(.serversList) })
        case .secondary:
            serversList
                .navigationTitle(L10n.Settings.ConnectionSection.addServer)
        }
    }

    @ViewBuilder
    private func view(for destination: OnboardingDestination) -> some View {
        switch destination {
        case .serversList:
            serversList
        case let .login(loginViewModel):
            OnboardingAuthLoginView(viewModel: loginViewModel)
        case let .deviceName(request):
            DeviceNameView(request: request)
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
        case let .permissions(server):
            OnboardingPermissionsNavigationView(
                onboardingServer: server,
                onDismiss: { finishFlow() }
            )
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var serversList: some View {
        OnboardingServersListView(
            prefillURL: prefillURL,
            shouldDismissOnSuccess: shouldDismissOnSuccess,
            onboardingStyle: onboardingStyle,
            presenter: presenter
        )
    }

    /// Ends onboarding after the permissions flow. The stack is popped to root without animation
    /// first so the container never tears the `NavigationStack` down while pages are pushed — doing
    /// so leaks the pushed page's hosting view over the app.
    private func finishFlow() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            presenter.popToRoot()
        }
        DispatchQueue.main.async {
            Current.onboardingObservation.complete()
        }
    }

    /// The trust alert can only be answered through its buttons; an unanswered request is kept so a
    /// follow-up presentation (retry after trusting) isn't dropped by the dismissal callback.
    private var certificateTrustAlertBinding: Binding<Bool> {
        Binding(
            get: { presenter.certificateTrustRequest != nil },
            set: { isPresented in
                if !isPresented, presenter.certificateTrustRequest?.isAnswered == true {
                    presenter.certificateTrustRequest = nil
                }
            }
        )
    }

    private func clientCertificateSheet(request: OnboardingClientCertificateRequest) -> some View {
        NavigationView {
            ClientCertificateOnboardingView(
                onImport: { certificate in
                    request.complete(with: certificate)
                },
                onCancel: {
                    request.cancel()
                }
            )
        }
        .navigationViewStyle(.stack)
        .presentationDetents([.medium])
        .onDisappear {
            // Interactive dismissal without a choice counts as cancelling the import.
            request.cancel()
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
