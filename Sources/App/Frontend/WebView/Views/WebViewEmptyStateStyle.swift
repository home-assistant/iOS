import Shared

enum WebViewEmptyStateStyle: Equatable {
    case disconnected
    /// Disconnected while flight detection says the user is on a plane — same recovery
    /// actions as `.disconnected`, with a friendlier header and greeting.
    case inFlight
    case unauthenticated
    /// The user signed out from the frontend. Same recovery action as `.unauthenticated`, with copy
    /// that reads as a deliberate log out rather than an expired session.
    case loggedOut
    case recoveredServerNeedingReauthentication

    enum HeaderAccessory {
        case none
        case settings
        case hiddenDismiss
    }

    var title: String {
        switch self {
        case .disconnected:
            L10n.WebView.EmptyState.title
        case .inFlight:
            L10n.FlightGreetings.EmptyState.title
        case .unauthenticated:
            L10n.Unauthenticated.Message.title
        case .loggedOut:
            L10n.WebView.EmptyState.LoggedOut.title
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.title
        }
    }

    var body: String {
        switch self {
        case .disconnected:
            L10n.WebView.EmptyState.body
        case .inFlight:
            L10n.FlightGreetings.EmptyState.body
        case .unauthenticated:
            L10n.Unauthenticated.Message.body
        case .loggedOut:
            L10n.WebView.EmptyState.LoggedOut.body
        case .recoveredServerNeedingReauthentication:
            ""
        }
    }

    var complementaryMessage: String? {
        switch self {
        case .inFlight:
            L10n.FlightGreetings.EmptyState.configureHint
        default:
            nil
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .disconnected, .inFlight:
            L10n.WebView.EmptyState.retryButton
        case .unauthenticated:
            L10n.WebView.EmptyState.reauthenticateButton
        case .loggedOut:
            L10n.WebView.EmptyState.LoggedOut.loginButton
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.continueButton
        }
    }

    var secondaryButtonTitle: String {
        switch self {
        case .disconnected, .inFlight, .unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication:
            L10n.WebView.EmptyState.openSettingsButton
        }
    }

    var leadingHeaderAccessory: HeaderAccessory {
        switch self {
        case .disconnected, .inFlight:
            .none
        case .unauthenticated, .loggedOut:
            .settings
        case .recoveredServerNeedingReauthentication:
            .none
        }
    }

    var trailingHeaderAccessory: HeaderAccessory {
        switch self {
        case .disconnected, .inFlight:
            .hiddenDismiss
        case .unauthenticated, .loggedOut:
            .none
        case .recoveredServerNeedingReauthentication:
            .settings
        }
    }

    var showsSecondarySettingsButton: Bool {
        switch self {
        case .disconnected, .inFlight:
            true
        case .unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication:
            false
        }
    }

    /// Whether the primary action is something the user has to do for the app to work again (rather than
    /// a retry it could also perform itself), which the warning-colored button signals.
    var primaryActionRequiresAttention: Bool {
        switch self {
        case .disconnected, .inFlight:
            false
        case .unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication:
            true
        }
    }

    var showsServerPicker: Bool {
        switch self {
        case .disconnected, .inFlight, .unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication:
            true
        }
    }

    var urlPickerTitle: String {
        switch self {
        case .disconnected, .inFlight, .unauthenticated:
            L10n.WebView.EmptyState.reauthenticateButton
        case .loggedOut:
            L10n.WebView.EmptyState.LoggedOut.loginButton
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.urlPickerTitle
        }
    }
}
