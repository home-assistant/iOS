import Shared

enum WebViewEmptyStateStyle: Equatable {
    case disconnected
    /// Disconnected while flight detection says the user is on a plane — same recovery
    /// actions as `.disconnected`, with a friendlier header and greeting.
    case inFlight
    case unauthenticated
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
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.continueButton
        }
    }

    var secondaryButtonTitle: String {
        switch self {
        case .disconnected, .inFlight, .unauthenticated, .recoveredServerNeedingReauthentication:
            L10n.WebView.EmptyState.openSettingsButton
        }
    }

    var leadingHeaderAccessory: HeaderAccessory {
        switch self {
        case .disconnected, .inFlight:
            .none
        case .unauthenticated:
            .settings
        case .recoveredServerNeedingReauthentication:
            .none
        }
    }

    var trailingHeaderAccessory: HeaderAccessory {
        switch self {
        case .disconnected, .inFlight:
            .hiddenDismiss
        case .unauthenticated:
            .none
        case .recoveredServerNeedingReauthentication:
            .settings
        }
    }

    var showsSecondarySettingsButton: Bool {
        switch self {
        case .disconnected, .inFlight:
            true
        case .unauthenticated, .recoveredServerNeedingReauthentication:
            false
        }
    }

    var showsServerPicker: Bool {
        switch self {
        case .disconnected, .inFlight, .unauthenticated, .recoveredServerNeedingReauthentication:
            true
        }
    }

    var urlPickerTitle: String {
        switch self {
        case .disconnected, .inFlight, .unauthenticated:
            L10n.WebView.EmptyState.reauthenticateButton
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.urlPickerTitle
        }
    }
}
