import Foundation
import Shared

/// A screen the onboarding flow asks its host to push onto the navigation stack. The flow advances by
/// replacing the destination in place (login → device naming → permissions) so it never bounces back
/// through the servers list between steps.
enum OnboardingAuthDestination {
    case login(OnboardingAuthLoginViewModel)
    case deviceName(OnboardingDeviceNameRequest)
    case permissions(Server)

    /// Stable identity per step, used to animate the in-place transition between steps.
    var stepID: String {
        switch self {
        case .login: return "login"
        case .deviceName: return "deviceName"
        case .permissions: return "permissions"
        }
    }
}
