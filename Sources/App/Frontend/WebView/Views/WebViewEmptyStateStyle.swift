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
    /// The server asked for a client certificate (mTLS) during the TLS handshake, but none is
    /// configured for this server on this device. The way back in is importing one.
    case clientCertificateRequired
    /// The server refused the client certificate configured for this server — expired, revoked or
    /// no longer the one the server expects. The way back in is importing a valid one.
    case clientCertificateRejected

    enum HeaderAccessory {
        case none
        case settings
        case hiddenDismiss
    }

    /// Builds the style for a client certificate problem the web view ran into.
    init(clientCertificateIssue: ClientCertificateIssue) {
        switch clientCertificateIssue {
        case .required:
            self = .clientCertificateRequired
        case .rejected:
            self = .clientCertificateRejected
        }
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
        case .clientCertificateRequired:
            L10n.WebView.EmptyState.ClientCertificate.Required.title
        case .clientCertificateRejected:
            L10n.WebView.EmptyState.ClientCertificate.Rejected.title
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
        case .recoveredServerNeedingReauthentication, .clientCertificateRequired, .clientCertificateRejected:
            // Server-specific copy, built by `WebViewEmptyStateMessage` from the server's name.
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
        case .clientCertificateRequired, .clientCertificateRejected:
            L10n.WebView.EmptyState.ClientCertificate.importButton
        }
    }

    var secondaryButtonTitle: String {
        switch self {
        case .disconnected, .inFlight, .unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication,
             .clientCertificateRequired, .clientCertificateRejected:
            L10n.WebView.EmptyState.openSettingsButton
        }
    }

    var leadingHeaderAccessory: HeaderAccessory {
        switch self {
        case .disconnected, .inFlight:
            .none
        case .unauthenticated, .loggedOut, .clientCertificateRequired, .clientCertificateRejected:
            .settings
        case .recoveredServerNeedingReauthentication:
            .none
        }
    }

    var trailingHeaderAccessory: HeaderAccessory {
        switch self {
        case .disconnected, .inFlight:
            .hiddenDismiss
        case .unauthenticated, .loggedOut, .clientCertificateRequired, .clientCertificateRejected:
            .none
        case .recoveredServerNeedingReauthentication:
            .settings
        }
    }

    var showsSecondarySettingsButton: Bool {
        switch self {
        case .disconnected, .inFlight:
            true
        case .unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication, .clientCertificateRequired,
             .clientCertificateRejected:
            false
        }
    }

    /// Whether the primary action is something the user has to do for the app to work again (rather than
    /// a retry it could also perform itself), which the warning-colored button signals.
    var primaryActionRequiresAttention: Bool {
        switch self {
        case .disconnected, .inFlight:
            false
        case .unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication, .clientCertificateRequired,
             .clientCertificateRejected:
            true
        }
    }

    var showsServerPicker: Bool {
        switch self {
        case .disconnected, .inFlight, .unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication,
             .clientCertificateRequired, .clientCertificateRejected:
            true
        }
    }

    /// Whether the style is one of the client certificate (mTLS) problems, whose primary action imports a
    /// certificate instead of retrying or re-authenticating.
    var isClientCertificateIssue: Bool {
        switch self {
        case .clientCertificateRequired, .clientCertificateRejected:
            true
        case .disconnected, .inFlight, .unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication:
            false
        }
    }

    var urlPickerTitle: String {
        switch self {
        case .disconnected, .inFlight, .unauthenticated, .clientCertificateRequired, .clientCertificateRejected:
            L10n.WebView.EmptyState.reauthenticateButton
        case .loggedOut:
            L10n.WebView.EmptyState.LoggedOut.loginButton
        case .recoveredServerNeedingReauthentication:
            L10n.Onboarding.ServerImport.Reauthenticate.urlPickerTitle
        }
    }
}
