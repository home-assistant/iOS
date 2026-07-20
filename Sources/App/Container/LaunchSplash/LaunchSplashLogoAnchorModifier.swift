import SwiftUI

/// Reports the global frame of a destination screen's Home Assistant logo to the launch splash overlay,
/// which morphs the splash logo into it before fading out. Attach to the logo of any screen that can be
/// the first one shown after launch (stand-by loading logo, onboarding welcome logo). Reporting is a
/// no-op once the launch transition already ran, so it is safe on screens that reappear later.
struct LaunchSplashLogoAnchorModifier: ViewModifier {
    var state: LaunchSplashOverlayState = .shared

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { state.registerDestinationLogoFrame(proxy.frame(in: .global)) }
                    .onChange(of: proxy.frame(in: .global)) { frame in
                        state.registerDestinationLogoFrame(frame)
                    }
            }
        )
    }
}

extension View {
    /// Marks this view as the logo the launch splash overlay should morph into. Apply after the logo's
    /// final `.frame` so the reported rect matches what is on screen.
    func launchSplashLogoAnchor(state: LaunchSplashOverlayState = .shared) -> some View {
        modifier(LaunchSplashLogoAnchorModifier(state: state))
    }
}
