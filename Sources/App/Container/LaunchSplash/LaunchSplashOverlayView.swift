import Shared
import SwiftUI

/// SwiftUI copy of `LaunchScreen.storyboard`, shown above the main window content at cold launch so the
/// hand-off from the system launch screen to the first real screen isn't noticeable: the splash wordmark
/// morphs (frame move + crossfade) into the destination screen's logo, then the overlay fades away.
/// Destinations opt in via `launchSplashLogoAnchor()`; screens without a logo are covered by the
/// fail-safe timeout and `fadeOut()`.
struct LaunchSplashOverlayView: View {
    /// Tweak these to adjust the transition; the previews below replay it.
    enum Constants {
        /// Mirrors the icon constraints in `LaunchScreen.storyboard`.
        static let splashLogoSize = CGSize(width: 115, height: 115)
        /// Mirrors the OHF logo constraints in `LaunchScreen.storyboard`.
        static let ohfLogoSize = CGSize(width: 320, height: 100)
        /// Mirrors the storyboard's OHF-logo-bottom-to-safe-area constraint.
        static let ohfLogoBottomPadding: CGFloat = 32
        static let heroAnimation: SwiftUI.Animation = .spring(response: 0.5, dampingFraction: 0.85)
        /// Kept in sync with `heroAnimation` — how long the overlay holds before starting to fade out.
        static let heroDuration: Duration = .seconds(1)
        static let fadeAnimation: SwiftUI.Animation = .easeOut(duration: 0.25)
        static let fadeDuration: Duration = .milliseconds(250)
        /// If no screen ever reports a logo (kiosk mode, unexpected flows), never block the app for
        /// longer than this.
        static let failSafeTimeout: Duration = .seconds(5)
    }

    @ObservedObject var state: LaunchSplashOverlayState

    var body: some View {
        if state.phase != .finished {
            // The outer ZStack respects the safe area so the OHF logo can pin to its bottom like the
            // storyboard does; only the hero content extends to the screen edges.
            ZStack(alignment: .bottom) {
                GeometryReader { proxy in
                    let frame = logoFrame(in: proxy)
                    ZStack(alignment: .topLeading) {
                        Color.launchScreenBackground
                        logo
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                    }
                    .animation(Constants.heroAnimation, value: state.phase)
                }
                .ignoresSafeArea()
                Image(.ohfLaunch)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Constants.ohfLogoSize.width, height: Constants.ohfLogoSize.height)
                    .padding(.bottom, Constants.ohfLogoBottomPadding)
            }
            .opacity(isFadingOut ? 0 : 1)
            .animation(Constants.fadeAnimation, value: isFadingOut)
            .allowsHitTesting(!isFadingOut)
            .accessibilityHidden(true)
            .onChange(of: state.phase) { phase in
                advance(after: phase)
            }
            .task {
                try? await Task.sleep(for: Constants.failSafeTimeout)
                state.fadeOut()
            }
        }
    }

    /// The splash wordmark and the destination logomark stacked so the hero can crossfade between them
    /// while the frame animates.
    private var logo: some View {
        ZStack {
            Image(.launchScreenLogo)
                .resizable()
                .scaledToFit()
                .opacity(showsSplashWordmark ? 1 : 0)
            Image(.logo)
                .resizable()
                .scaledToFit()
                .opacity(showsSplashWordmark ? 0 : 1)
        }
    }

    private var showsSplashWordmark: Bool {
        switch state.phase {
        case .waiting, .fadingOut(logoFrame: nil), .finished:
            true
        case .matching, .fadingOut:
            false
        }
    }

    private var isFadingOut: Bool {
        if case .fadingOut = state.phase { return true }
        return false
    }

    private func logoFrame(in proxy: GeometryProxy) -> CGRect {
        switch state.phase {
        case .waiting, .finished, .fadingOut(logoFrame: nil):
            splashLogoFrame(in: proxy.size)
        case let .matching(logoFrame: frame), let .fadingOut(logoFrame: frame?):
            // Anchors report in the global space; convert into this overlay's coordinate space.
            frame.offsetBy(
                dx: -proxy.frame(in: .global).minX,
                dy: -proxy.frame(in: .global).minY
            )
        }
    }

    /// Centered like the storyboard's centerX/centerY constraints against the full screen.
    private func splashLogoFrame(in size: CGSize) -> CGRect {
        CGRect(
            x: (size.width - Constants.splashLogoSize.width) / 2,
            y: (size.height - Constants.splashLogoSize.height) / 2,
            width: Constants.splashLogoSize.width,
            height: Constants.splashLogoSize.height
        )
    }

    /// Runs the choreography: once the hero lands, fade the overlay; once faded, remove it.
    private func advance(after phase: LaunchSplashOverlayState.Phase) {
        switch phase {
        case .matching:
            Task {
                try? await Task.sleep(for: Constants.heroDuration)
                state.fadeOut()
            }
        case .fadingOut:
            Task {
                try? await Task.sleep(for: Constants.fadeDuration)
                state.finish()
            }
        case .waiting, .finished:
            break
        }
    }
}

#Preview("Splash copy (static, compare with storyboard)") {
    LaunchSplashOverlayView(state: LaunchSplashOverlayState())
}

#Preview("Hero over Stand By") {
    // The stand-by logo anchor reports to `.shared`, so the transition auto-plays once on preview
    // launch at real-app speed; use Replay for a version that holds on the splash first.
    ZStack {
        HomeAssistantStandByView(server: ServerFixture.standard, emptyState: nil)
        LaunchSplashOverlayView(state: .shared)
    }
    .overlay(alignment: .bottomTrailing) {
        Button("Replay") { LaunchSplashOverlayState.shared.replayForPreviews() }
            .buttonStyle(.borderedProminent)
            .padding()
    }
}

#Preview("Hero over Onboarding Welcome") {
    ZStack {
        NavigationView {
            OnboardingWelcomeView(continueAction: {})
        }
        .navigationViewStyle(.stack)
        LaunchSplashOverlayView(state: .shared)
    }
    .overlay(alignment: .bottomTrailing) {
        Button("Replay") { LaunchSplashOverlayState.shared.replayForPreviews() }
            .buttonStyle(.borderedProminent)
            .padding()
    }
}

#Preview("Fail-safe fade (no logo reported)") {
    // No anchor ever reports here, so the overlay fades out on its own after `failSafeTimeout`.
    ZStack {
        Text(verbatim: "Screen without a logo")
        LaunchSplashOverlayView(state: LaunchSplashOverlayState())
    }
}
