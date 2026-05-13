import Shared

enum WebViewEmptyStateStyle: Equatable {
    case disconnected
    case unauthenticated
    case recoveredServerNeedingReauthentication

    enum HeaderAccessory {
        case none
        case settings
        case close
    }

    var title: String {
        switch self {
        case .disconnected:
            L10n.WebView.EmptyState.title
        case .unauthenticated:
            L10n.Unauthenticated.Message.title
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.title
        }
    }

    var body: String {
        switch self {
        case .disconnected:
            L10n.WebView.EmptyState.body
        case .unauthenticated:
            L10n.Unauthenticated.Message.body
        case .recoveredServerNeedingReauthentication:
            ""
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .disconnected:
            L10n.WebView.EmptyState.retryButton
        case .unauthenticated:
            L10n.WebView.EmptyState.reauthenticateButton
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.continueButton
        }
    }

    var secondaryButtonTitle: String {
        switch self {
        case .disconnected, .unauthenticated, .recoveredServerNeedingReauthentication:
            L10n.WebView.EmptyState.openSettingsButton
        }
    }

    var leadingHeaderAccessory: HeaderAccessory {
        switch self {
        case .disconnected:
            .none
        case .unauthenticated:
            .settings
        case .recoveredServerNeedingReauthentication:
            .none
        }
    }

    var trailingHeaderAccessory: HeaderAccessory {
        switch self {
        case .disconnected, .unauthenticated:
            .close
        case .recoveredServerNeedingReauthentication:
            .settings
        }
    }

    var showsSecondarySettingsButton: Bool {
        switch self {
        case .disconnected:
            true
        case .unauthenticated, .recoveredServerNeedingReauthentication:
            false
        }
    }

    var showsServerPicker: Bool {
        switch self {
        case .disconnected, .unauthenticated, .recoveredServerNeedingReauthentication:
            true
        }
    }

    var urlPickerTitle: String {
        switch self {
        case .disconnected, .unauthenticated:
            L10n.WebView.EmptyState.reauthenticateButton
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.urlPickerTitle
        }
    }
}
