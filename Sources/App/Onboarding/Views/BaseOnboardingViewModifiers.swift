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

/// A view modifier that conditionally disables the primary action button in BaseOnboardingView
public struct DisabledPrimaryActionModifier: ViewModifier {
    let isDisabled: Bool

    public func body(content: Content) -> some View {
        content
            .environment(\.disableOnboardingPrimaryAction, isDisabled)
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

/// Environment key for disabling the primary action button
private struct DisableOnboardingPrimaryActionKey: EnvironmentKey {
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

    var disableOnboardingPrimaryAction: Bool {
        get { self[DisableOnboardingPrimaryActionKey.self] }
        set { self[DisableOnboardingPrimaryActionKey.self] = newValue }
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

    /// Conditionally disables the primary action button in BaseOnboardingView
    /// - Parameter isDisabled: When true, the primary button will be disabled
    /// - Returns: A view with the primary action disabled state modifier applied
    func disableOnboardingPrimaryAction(_ isDisabled: Bool) -> some View {
        modifier(DisabledPrimaryActionModifier(isDisabled: isDisabled))
    }
}
