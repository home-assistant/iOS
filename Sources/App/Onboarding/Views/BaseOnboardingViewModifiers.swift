import SwiftUI

/// A view modifier that conditionally hides the header in BaseOnboardingView
public struct HiddenHeaderModifier: ViewModifier {
    let hideHeader: Bool

    public func body(content: Content) -> some View {
        content
            .environment(\.hideOnboardingHeader, hideHeader)
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
