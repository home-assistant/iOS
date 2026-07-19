import Combine
import Shared

/// Drives the content presented over the web frontend — launch messages (What's-New, then TestFlight),
/// Settings, the download manager (sheets), and the forced onboarding-permissions decision (full-screen
/// cover). Owns the launch queue and publishes the currently-presented content for `ContainerView`.
@MainActor
final class ContainerViewModel: ObservableObject {
    /// A sheet presented over the web view. A single `.sheet(item:)` switches on this, so only one can be
    /// presented at a time regardless of how many qualify.
    enum PresentedSheet: Identifiable {
        case whatsNew(WhatsNewRelease)
        case testFlight(TestFlightMessage)
        case assistSettings
        case downloadManager(DownloadManagerViewModel)
        case serverSelect(prompt: String?, includeSettings: Bool, onSelect: (Server) -> Void)

        var id: String {
            switch self {
            case let .whatsNew(release): return "whatsNew-\(release.id)"
            case let .testFlight(message): return "testFlight-\(message.id.rawValue)"
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

    private var pendingLaunchMessages: [PresentedSheet] = []
    private var didEvaluateLaunchMessages = false

    /// Queues the launch messages (What's-New, then TestFlight) to present the first time the web view appears
    /// — the first thing the user sees — via SwiftUI rather than a UIKit overlay.
    func presentLaunchMessagesIfNeeded(isShowingWebView: Bool) {
        guard !didEvaluateLaunchMessages, isShowingWebView else { return }
        didEvaluateLaunchMessages = true

        var queue: [PresentedSheet] = []
        if let release = WhatsNewEngine().releaseToShow() {
            queue.append(.whatsNew(release))
        }
        if let message = TestFlightCommunicationEngine().messageToShow() {
            queue.append(.testFlight(message))
        }
        pendingLaunchMessages = queue
        // This is evaluated from the onboarding → web view screen swap. Presenting the sheet in the same
        // transaction as the swap (which itself rides the tail of the permissions cover dismissal) corrupts
        // UIKit's presentation state: the old onboarding view stays installed and the web view never attaches.
        // Delay the first message until the new hierarchy has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.showNextLaunchMessage()
        }
    }

    /// Presents the next queued launch message, if any. Called on first evaluation and on each sheet dismiss so
    /// a single `.sheet` shows them in sequence — only one is ever bound, avoiding competing-binding races.
    func showNextLaunchMessage() {
        guard presentedSheet == nil, !pendingLaunchMessages.isEmpty else { return }
        presentedSheet = pendingLaunchMessages.removeFirst()
    }

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
