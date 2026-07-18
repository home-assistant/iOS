import Foundation
import SwiftUI

/// Drives `LaunchSplashOverlayView`, the SwiftUI copy of the launch screen shown above the main window
/// content at cold launch. The first screen with a Home Assistant logo (stand-by, onboarding welcome)
/// reports its logo frame through `launchSplashLogoAnchor()`, which starts the hero transition; screens
/// without a logo call `fadeOut()` so the overlay never blocks them.
@MainActor
final class LaunchSplashOverlayState: ObservableObject {
    enum Phase: Equatable {
        /// Showing the static splash copy, waiting for the first screen to report its logo.
        case waiting
        /// Morphing the splash logo into the destination logo frame (global coordinates).
        case matching(logoFrame: CGRect)
        /// Fading the whole overlay out; keeps the matched frame so the logo doesn't jump.
        case fadingOut(logoFrame: CGRect?)
        /// The overlay is gone; terminal for the rest of the app session.
        case finished
    }

    static let shared = LaunchSplashOverlayState()

    @Published private(set) var phase: Phase = .waiting

    /// Last frame reported by a destination logo, kept so previews can replay the transition.
    private(set) var latestDestinationLogoFrame: CGRect?

    /// Called by `launchSplashLogoAnchor()` whenever a destination logo lays out. The first report starts
    /// the hero transition; re-layout while the hero runs retargets it; anything later is a no-op.
    func registerDestinationLogoFrame(_ frame: CGRect) {
        guard frame.width > 0, frame.height > 0 else { return }
        latestDestinationLogoFrame = frame
        switch phase {
        case .waiting, .matching:
            phase = .matching(logoFrame: frame)
        case .fadingOut, .finished:
            break
        }
    }

    /// Fades the overlay without a hero transition — used by screens that have no logo to match and by
    /// the overlay's fail-safe timeout. Keeps the matched frame when the hero already ran.
    func fadeOut() {
        switch phase {
        case .waiting:
            phase = .fadingOut(logoFrame: nil)
        case let .matching(logoFrame):
            phase = .fadingOut(logoFrame: logoFrame)
        case .fadingOut, .finished:
            break
        }
    }

    /// Removes the overlay once the fade completed.
    func finish() {
        guard case .fadingOut = phase else { return }
        phase = .finished
    }

    /// Replays the whole splash → hero → fade sequence, holding on the splash briefly so the transition
    /// is watchable. Only meant for Xcode previews.
    func replayForPreviews() {
        phase = .waiting
        guard let frame = latestDestinationLogoFrame else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            registerDestinationLogoFrame(frame)
        }
    }
}
