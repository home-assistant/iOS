import SwiftUI

/// A view modifier that conditionally hides the title in BaseOnboardingView
public struct HiddenTitleModifier: ViewModifier {
    let hideTitle: Bool

    public func body(content: Content) -> some View {
        content
            .environment(\.hideOnboardingTitle, hideTitle)
    }
}

/// A view modifier that conditionally hides the icon/illustration in BaseOnboardingView
public struct HiddenIconModifier: ViewModifier {
    let hideIcon: Bool

    public func body(content: Content) -> some View {
        content
            .environment(\.hideOnboardingIcon, hideIcon)
    }
}

/// Environment key for hiding the onboarding title
private struct HideOnboardingTitleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

/// Environment key for hiding the onboarding icon/illustration
private struct HideOnboardingIconKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var hideOnboardingTitle: Bool {
        get { self[HideOnboardingTitleKey.self] }
        set { self[HideOnboardingTitleKey.self] = newValue }
    }

    var hideOnboardingIcon: Bool {
        get { self[HideOnboardingIconKey.self] }
        set { self[HideOnboardingIconKey.self] = newValue }
    }
}

public extension View {
    /// Conditionally hides the title in BaseOnboardingView
    /// - Parameter hideTitle: When true, the title will be hidden
    /// - Returns: A view with the title visibility modifier applied
    func hideOnboardingTitle(_ hideTitle: Bool) -> some View {
        modifier(HiddenTitleModifier(hideTitle: hideTitle))
    }

    /// Conditionally hides the icon/illustration in BaseOnboardingView
    /// - Parameter hideIcon: When true, the icon/illustration will be hidden
    /// - Returns: A view with the icon visibility modifier applied
    func hideOnboardingIcon(_ hideIcon: Bool) -> some View {
        modifier(HiddenIconModifier(hideIcon: hideIcon))
    }
}
