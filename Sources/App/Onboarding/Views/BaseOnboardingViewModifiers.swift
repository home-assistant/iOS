import SwiftUI

/// A view modifier that conditionally hides the header in BaseOnboardingView
public struct HiddenHeaderModifier: ViewModifier {
    let hideHeader: Bool

    public func body(content: Content) -> some View {
        content
            .environment(\.hideOnboardingHeader, hideHeader)
    }
}

/// A view modifier that animates hiding content by collapsing its frame and adjusting opacity
struct AnimatedHidingModifier: ViewModifier {
    let isHidden: Bool

    func body(content: Content) -> some View {
        content
            .frame(height: isHidden ? 0 : nil)
            .opacity(isHidden ? 0 : 1)
            .hidden(isHidden)
            .animation(.easeInOut(duration: 0.3), value: isHidden)
    }
}

/// Environment key for hiding the onboarding header
private struct HideOnboardingHeaderKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var hideOnboardingHeader: Bool {
        get { self[HideOnboardingHeaderKey.self] }
        set { self[HideOnboardingHeaderKey.self] = newValue }
    }
}

public extension View {
    /// Conditionally hides the header in BaseOnboardingView
    /// - Parameter hideHeader: When true, the header will be hidden
    /// - Returns: A view with the header visibility modifier applied
    func hideOnboardingHeader(_ hideHeader: Bool) -> some View {
        modifier(HiddenHeaderModifier(hideHeader: hideHeader))
    }
}
