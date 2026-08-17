import Shared
import SwiftUI

/// Full-screen connection/re-authentication empty state, used by the recovered-server re-authentication
/// flow. The web view path renders the same content (`WebViewEmptyStateHeader`, `WebViewEmptyStateIcon`,
/// `WebViewEmptyStateMessage`, `WebViewEmptyStateActionButtons`) inside `HomeAssistantStandByView`.
struct WebViewEmptyStateView: View {
    let style: WebViewEmptyStateStyle
    let server: Server
    let isLoading: Bool
    let showsErrorDetailsButton: Bool
    let availableReauthURLTypes: [ConnectionInfo.URLType]
    let retryAction: (() -> Void)?
    let settingsAction: (() -> Void)?
    let errorDetailsAction: (() -> Void)?
    let reauthAction: ((ConnectionInfo.URLType) -> Void)?
    let recoveredServerReauthAction: ((ConnectionInfo.URLType, @escaping (Swift.Result<Void, Error>) -> Void) -> Void)?
    let serverSelectionAction: ((Server) -> Void)?
    let dismissAction: (() -> Void)?

    init(
        style: WebViewEmptyStateStyle,
        server: Server,
        isLoading: Bool = false,
        showsErrorDetailsButton: Bool = false,
        availableReauthURLTypes: [ConnectionInfo.URLType] = [],
        retryAction: (() -> Void)? = nil,
        settingsAction: (() -> Void)? = nil,
        errorDetailsAction: (() -> Void)? = nil,
        reauthAction: ((ConnectionInfo.URLType) -> Void)? = nil,
        recoveredServerReauthAction: (
            (ConnectionInfo.URLType, @escaping (Swift.Result<Void, Error>) -> Void) -> Void
        )? =
            nil,
        serverSelectionAction: ((Server) -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.style = style
        self.server = server
        self.isLoading = isLoading
        self.showsErrorDetailsButton = showsErrorDetailsButton
        self.availableReauthURLTypes = availableReauthURLTypes
        self.retryAction = retryAction
        self.settingsAction = settingsAction
        self.errorDetailsAction = errorDetailsAction
        self.reauthAction = reauthAction
        self.recoveredServerReauthAction = recoveredServerReauthAction
        self.serverSelectionAction = serverSelectionAction
        self.dismissAction = dismissAction
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            WebViewEmptyStateIcon(style: style)
            WebViewEmptyStateMessage(
                style: style,
                server: server,
                complementaryMessageAction: { settingsAction?() }
            )
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spaces.three)
        .padding(.top, DesignSystem.Spaces.five)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .safeAreaInset(edge: .top) {
            WebViewEmptyStateHeader(
                style: style,
                server: server,
                isLoading: isLoading,
                showsServerSelection: style.showsServerPicker && Current.servers.all.count > 1,
                showsErrorDetailsButton: canShowErrorDetailsButton,
                settingsAction: { settingsAction?() },
                serverSelectionAction: selectServer,
                dismissAction: { dismissAction?() }
            )
        }
        .safeAreaInset(edge: .bottom) {
            WebViewEmptyStateActionButtons(
                style: style,
                availableReauthURLTypes: availableReauthURLTypes,
                showsErrorDetailsButton: canShowErrorDetailsButton,
                retryAction: { retryAction?() },
                settingsAction: { settingsAction?() },
                errorDetailsAction: { errorDetailsAction?() },
                reauthAction: { reauthAction?($0) },
                recoveredServerReauthAction: recoveredServerReauthAction
            )
        }
    }

    private var canShowErrorDetailsButton: Bool {
        style == .disconnected && showsErrorDetailsButton && errorDetailsAction != nil
    }

    private func selectServer(_ server: Server) {
        if let serverSelectionAction {
            serverSelectionAction(server)
        } else {
            Current.sceneManager.appCoordinator.done { coordinator in
                coordinator.activate(server: server)
            }
        }
    }
}

#Preview("Disconnected") {
    WebViewEmptyStatePreview.view(style: .disconnected)
}

#Preview("Disconnected Loading") {
    WebViewEmptyStatePreview.view(style: .disconnected, isLoading: true)
}

#Preview("Disconnected With Error Details") {
    WebViewEmptyStatePreview.view(
        style: .disconnected,
        showsErrorDetailsButton: true,
        errorDetailsAction: {}
    )
}

#Preview("Unauthenticated") {
    WebViewEmptyStatePreview.view(
        style: .unauthenticated,
        availableReauthURLTypes: [.external],
        reauthAction: { _ in }
    )
}

#Preview("Unauthenticated Multiple URLs") {
    WebViewEmptyStatePreview.view(
        style: .unauthenticated,
        availableReauthURLTypes: [.remoteUI, .external, .internal],
        reauthAction: { _ in }
    )
}

#Preview("Recovered Server Reauthentication") {
    WebViewEmptyStatePreview.view(
        style: .recoveredServerNeedingReauthentication,
        availableReauthURLTypes: [.remoteUI, .external],
        recoveredServerReauthAction: { _, completion in
            completion(.success(()))
        }
    )
}

#Preview("Recovered Server Reauthentication Dark") {
    WebViewEmptyStatePreview.view(
        style: .recoveredServerNeedingReauthentication,
        availableReauthURLTypes: [.remoteUI, .external],
        recoveredServerReauthAction: { _, completion in
            completion(.failure(NSError(
                domain: "Preview",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Reauthentication failed."]
            )))
        }
    )
    .preferredColorScheme(.dark)
}

private enum WebViewEmptyStatePreview {
    static func view(
        style: WebViewEmptyStateStyle,
        isLoading: Bool = false,
        showsErrorDetailsButton: Bool = false,
        availableReauthURLTypes: [ConnectionInfo.URLType] = [],
        errorDetailsAction: (() -> Void)? = nil,
        reauthAction: ((ConnectionInfo.URLType) -> Void)? = nil,
        recoveredServerReauthAction: ((
            ConnectionInfo.URLType,
            @escaping (Swift.Result<Void, Error>) -> Void
        ) -> Void)? = nil
    ) -> some View {
        WebViewEmptyStateView(
            style: style,
            server: ServerFixture.standard,
            isLoading: isLoading,
            showsErrorDetailsButton: showsErrorDetailsButton,
            availableReauthURLTypes: availableReauthURLTypes,
            retryAction: {},
            settingsAction: {},
            errorDetailsAction: errorDetailsAction,
            reauthAction: reauthAction,
            recoveredServerReauthAction: recoveredServerReauthAction,
            serverSelectionAction: { _ in },
            dismissAction: {}
        )
    }
}
