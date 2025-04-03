import Shared

enum OnboardingStyle: Equatable {
    enum RequiredType: Equatable {
        case full
        case permissions
    }

    case initial
    case required(RequiredType)
    case secondary

    var insertsCancelButton: Bool {
        switch self {
        case .initial, .required: return false
        case .secondary: return true
        }
    }
}

enum OnboardingNavigationViewController {
    public static var requiredOnboardingStyle: OnboardingStyle? {
        if Current.servers.all.isEmpty {
            return .required(.full)
        } else if !OnboardingPermissionHandler.notDeterminedPermissions.isEmpty {
            return .required(.permissions)
        } else {
            return nil
        }
    }
}
