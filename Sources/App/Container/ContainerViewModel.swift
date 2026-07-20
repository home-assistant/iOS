import Combine
import Shared

/// Drives the content presented over the web frontend — Settings, the download manager (sheets), and
/// the forced onboarding-permissions decision (full-screen cover). Publishes the currently-presented
/// content for `ContainerView`. What's-New / TestFlight launch messages are owned by
/// `HomeAssistantView` so they can only ever present over the web frontend, never over onboarding.
@MainActor
final class ContainerViewModel: ObservableObject {
    /// A sheet presented over the web view. A single `.sheet(item:)` switches on this, so only one can be
    /// presented at a time regardless of how many qualify.
    enum PresentedSheet: Identifiable {
        case assistSettings
        case downloadManager(DownloadManagerViewModel)
        case serverSelect(prompt: String?, includeSettings: Bool, onSelect: (Server) -> Void)

        var id: String {
            switch self {
            case .assistSettings: return "assistSettings"
            case .downloadManager: return "downloadManager"
            case .serverSelect: return "serverSelect"
            }
        }
    }

    /// A forced, full-screen flow presented over the web view via `.fullScreenCover` (no swipe-to-dismiss).
    enum FullScreenCover: Identifiable {
        case onboardingPermissions(server: Server, steps: [OnboardingPermissionsNavigationViewModel.StepID])

        var id: String {
            switch self {
            case .onboardingPermissions: return "onboardingPermissions"
            }
        }
    }

    @Published var presentedSheet: PresentedSheet?
    @Published var fullScreenCover: FullScreenCover?

    /// Presents Assist settings as a sheet over the web view (triggered by the frontend's external bus).
    func presentAssistSettings() {
        presentedSheet = .assistSettings
    }

    /// Presents the download manager as a sheet (iOS 17+, a download began). The view model must be the same
    /// instance the web view set as the `WKDownload` delegate.
    func presentDownloadManager(_ viewModel: DownloadManagerViewModel) {
        presentedSheet = .downloadManager(viewModel)
    }

    /// Presents the forced onboarding-permissions decision as a full-screen cover.
    func presentOnboardingPermissions(server: Server, steps: [OnboardingPermissionsNavigationViewModel.StepID]) {
        fullScreenCover = .onboardingPermissions(server: server, steps: steps)
    }

    /// Presents the server picker as a sheet (e.g. a server-less deep link, or the "show servers" gesture).
    func presentServerSelect(prompt: String?, includeSettings: Bool, onSelect: @escaping (Server) -> Void) {
        presentedSheet = .serverSelect(prompt: prompt, includeSettings: includeSettings, onSelect: onSelect)
    }
}
