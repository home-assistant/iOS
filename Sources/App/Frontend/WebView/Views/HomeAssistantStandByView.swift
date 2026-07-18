import SFSafeSymbols
import Shared
import SwiftUI

struct HomeAssistantStandByView: View {
    static let dismissTapThreshold = 5
    static let logoDismissTapThreshold = 10

    private static let headerAccessorySize = CGSize(width: 44, height: 44)
    private static let loadingLogoSize = CGSize(width: 110, height: 110)
    private static let emptyStateLogoSize = CGSize(width: 80, height: 80)
    private static let reauthenticationIconSize: CGFloat = 56
    private static let serverPillHeight: CGFloat = 44
    private static let delayedSettingsButtonDelay: Duration = .seconds(5)
    private static let connectionTypeToastID = "home-assistant-stand-by-connection-type"
    fileprivate static let launchScreenLogoSize = CGSize(width: 147, height: 174)
    fileprivate static let launchScreenLogoPreviewOpacity = 0.55

    let server: Server
    let emptyState: WebFrontendOverlayState.EmptyStateContent?
    let isLoading: Bool
    let onGestureAction: ((HAGestureAction) -> Void)?
    let onLogoDismiss: (() -> Void)?

    @State private var selectedReauthURLType: ConnectionInfo.URLType
    @State private var showURLPicker = false
    @State private var isPerformingPrimaryAction = false
    @State private var errorMessage: String?
    @State private var dismissTapCount = 0
    @State private var logoDismissTapCount = 0
    @State private var showsEmptyStateContent = false
    @State private var showsDelayedSettingsButton = false
    @State private var hasAppeared = false

    private var showsEmptyState: Bool { emptyState != nil }
    private var loadingContentOffset: CGFloat { showsEmptyState ? 0 : -DesignSystem.Spaces.eight }
    private var standByContentOpacity: Double { hasAppeared ? 1.0 : 0.0 }
    private var contentOpacity: Double { showsEmptyStateContent ? 1.0 : 0.0 }
    private var configuredURLTypes: [ConnectionInfo.URLType] {
        [.internal, .external, .remoteUI].filter { urlType in
            switch urlType {
            case .remoteUI:
                server.info.connection.useCloud && server.info.connection.address(for: urlType) != nil
            case .internal, .external:
                server.info.connection.address(for: urlType) != nil
            case .none:
                false
            }
        }
    }

    private var showsConnectionTypeIndicator: Bool { configuredURLTypes.count > 1 }

    init(
        server: Server,
        emptyState: WebFrontendOverlayState.EmptyStateContent?,
        isLoading: Bool = false,
        onGestureAction: ((HAGestureAction) -> Void)? = nil,
        onLogoDismiss: (() -> Void)? = nil
    ) {
        self.server = server
        self.emptyState = emptyState
        self.isLoading = isLoading
        self.onGestureAction = onGestureAction
        self.onLogoDismiss = onLogoDismiss
        self._selectedReauthURLType = State(initialValue: emptyState?.availableReauthURLTypes.first ?? .external)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: DesignSystem.Spaces.three) {
                iconView
                if let emptyState {
                    emptyStateBody(for: emptyState)
                } else {
                    currentServerPill
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.three)
            .padding(.top, showsEmptyState ? DesignSystem.Spaces.five : 0)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: showsEmptyState ? .top : .center
            )
            .offset(y: loadingContentOffset)
            .opacity(standByContentOpacity)
            progressView
        }
        // Sits in front of the background colour but behind the content, so swipes over empty areas reach it
        // while buttons keep priority.
        .background {
            if let onGestureAction {
                WebFrontendGesturesOverlay(onGestureAction: onGestureAction)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .topLeading) {
            delayedSettingsButton
        }
        .safeAreaInset(edge: .top) {
            if let emptyState {
                header(for: emptyState)
                    .opacity(contentOpacity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let emptyState {
                actionButtons(for: emptyState)
                    .opacity(contentOpacity)
            }
        }
        .alert(L10n.errorLabel, isPresented: .init(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )) {
            Button(L10n.okLabel, role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .animation(DesignSystem.Animation.default, value: standByContentOpacity)
        .animation(DesignSystem.Animation.default, value: showsEmptyState)
        .onAppear {
            withAnimation(DesignSystem.Animation.default) {
                hasAppeared = true
                showsEmptyStateContent = emptyState != nil
            }
        }
        .onChange(of: emptyState != nil) { showsEmptyState in
            withAnimation(DesignSystem.Animation.default) {
                showsEmptyStateContent = showsEmptyState
            }
        }
        .onChange(of: emptyState?.availableReauthURLTypes ?? []) { availableReauthURLTypes in
            selectedReauthURLType = availableReauthURLTypes.first ?? .external
        }
        .task(id: showsEmptyState) {
            showsDelayedSettingsButton = false
            guard !showsEmptyState else { return }
            try? await Task.sleep(for: Self.delayedSettingsButtonDelay)
            guard !Task.isCancelled, !showsEmptyState else { return }
            withAnimation(DesignSystem.Animation.default) {
                showsDelayedSettingsButton = true
            }
        }
    }

    @ViewBuilder
    private var progressView: some View {
        if emptyState == nil {
            HAProgressView()
                .transition(.opacity)
                .padding(.bottom, DesignSystem.Spaces.eighteen)
        }
    }

    @ViewBuilder
    private var delayedSettingsButton: some View {
        if !showsEmptyState, showsDelayedSettingsButton {
            ModalReusableButton(
                icon: .sfSymbol(.gearshape),
                action: openSettings
            )
            .accessibilityLabel(L10n.WebView.EmptyState.openSettingsButton)
            .padding()
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func emptyStateBody(for emptyState: WebFrontendOverlayState.EmptyStateContent) -> some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(emptyState.style.title)
                .font(.title2)
                .fontWeight(.semibold)
            bodyText(for: emptyState)
        }
        .opacity(contentOpacity)
        .transition(.opacity)
        Spacer()
    }

    @ViewBuilder
    private var currentServerPill: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                currentServerPillContent
            }
        } else {
            currentServerPillContent
        }
    }

    private var currentServerPillContent: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            Text(server.info.name)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, DesignSystem.Spaces.two)
                .frame(height: Self.serverPillHeight)
                .modify { view in
                    if #available(iOS 26.0, *) {
                        view
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .contentShape(Capsule())
                    } else {
                        view
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(.capsule)
                    }
                }
            if showsConnectionTypeIndicator {
                connectionTypeIndicator
            }
        }
    }

    private var connectionTypeIndicator: some View {
        Button(action: showConnectionTypeToast) {
            Image(systemSymbol: connectionTypeIndicatorIcon)
                .font(.headline)
                .foregroundStyle(Color.haPrimary)
                .frame(width: Self.serverPillHeight, height: Self.serverPillHeight)
                .modify { view in
                    if #available(iOS 26.0, *) {
                        view
                            .frame(width: Self.headerAccessorySize.width, height: Self.headerAccessorySize.height)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .contentShape(Circle())
                    } else {
                        view
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(.circle)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Connection.ActiveUrlType.Toast.title)
    }

    private var connectionTypeIndicatorIcon: SFSymbol {
        switch server.info.connection.activeURLType {
        case .internal:
            .houseFill
        case .remoteUI:
            .cloudFill
        case .external:
            .network
        case .none:
            .wifiExclamationmark
        }
    }

    private var connectionTypeToastMessage: String {
        switch server.info.connection.activeURLType {
        case .internal:
            L10n.Connection.ActiveUrlType.Toast.internal
        case .remoteUI:
            L10n.Connection.ActiveUrlType.Toast.remoteUi
        case .external:
            L10n.Connection.ActiveUrlType.Toast.external
        case .none:
            L10n.Connection.ActiveUrlType.Toast.none
        }
    }

    private func showConnectionTypeToast() {
        if #available(iOS 18, *) {
            ToastPresenter.shared.show(
                id: Self.connectionTypeToastID,
                symbol: connectionTypeIndicatorIcon,
                symbolForegroundStyle: (.white, .haPrimary),
                title: L10n.Connection.ActiveUrlType.Toast.title,
                message: connectionTypeToastMessage,
                duration: 4
            )
        } else {
            Current.Log.verbose("Not showing connection type toast, Toast not available on this OS version.")
        }
    }

    @ViewBuilder
    private var iconView: some View {
        Group {
            if emptyState?.style == .recoveredServerNeedingReauthentication {
                Image(systemSymbol: .key)
                    .font(.system(size: Self.reauthenticationIconSize))
                    .foregroundStyle(Color.haPrimary)
            } else {
                Image(.logo)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(
            width: showsEmptyState ? Self.emptyStateLogoSize.width : Self.loadingLogoSize.width,
            height: showsEmptyState ? Self.emptyStateLogoSize.height : Self.loadingLogoSize.height
        )
        .launchSplashLogoAnchor()
        .contentShape(Rectangle())
        .onTapGesture(perform: registerLogoDismissTap)
    }

    private func header(for emptyState: WebFrontendOverlayState.EmptyStateContent) -> some View {
        HStack {
            headerAccessory(resolvedLeadingHeaderAccessory(for: emptyState))
            Spacer()
            serverSelection(for: emptyState)
            Spacer()
            headerAccessory(emptyState.style.trailingHeaderAccessory)
        }
        .padding()
    }

    @ViewBuilder
    private func headerAccessory(_ accessory: WebViewEmptyStateStyle.HeaderAccessory) -> some View {
        switch accessory {
        case .none:
            Color.clear
                .frame(width: Self.headerAccessorySize.width, height: Self.headerAccessorySize.height)
        case .settings:
            ModalReusableButton(
                icon: .sfSymbol(.gearshape),
                action: {
                    emptyState?.settingsAction()
                }
            )
            .accessibilityLabel(L10n.WebView.EmptyState.openSettingsButton)
        case .hiddenDismiss:
            Color.clear
                .frame(width: Self.headerAccessorySize.width, height: Self.headerAccessorySize.height)
                .overlay {
                    if isLoading {
                        ProgressView()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: registerDismissTap)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func serverSelection(for emptyState: WebFrontendOverlayState.EmptyStateContent) -> some View {
        if emptyState.style.showsServerPicker, Current.servers.all.count > 1 {
            if Current.isCatalyst {
                Menu {
                    ForEach(Current.servers.all, id: \.identifier) { availableServer in
                        Button {
                            selectServer(availableServer)
                        } label: {
                            Label(
                                availableServer.info.name,
                                systemSymbol: availableServer.identifier == server.identifier ? .checkmark : .serverRack
                            )
                        }
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: .serverRack)
                            .foregroundStyle(Color.haPrimary)
                        Text(server.info.name)
                            .font(.callout)
                            .lineLimit(1)
                        Image(systemSymbol: .chevronUpChevronDown)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DesignSystem.Spaces.two)
                    .padding(.vertical, DesignSystem.Spaces.one)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            } else {
                ServerPickerView(server: server, onSelect: selectServer)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private func bodyText(for emptyState: WebFrontendOverlayState.EmptyStateContent) -> some View {
        switch emptyState.style {
        case .disconnected, .unauthenticated:
            Text(emptyState.style.body)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)
        case .recoveredServerNeedingReauthentication:
            Text(L10n.Onboarding.ServerImport.Reauthenticate.message(server.info.name))
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)
        }
    }

    private func actionButtons(for emptyState: WebFrontendOverlayState.EmptyStateContent) -> some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Button(action: {
                switch emptyState.style {
                case .disconnected:
                    emptyState.retryAction()
                case .unauthenticated:
                    emptyState.reauthAction(selectedReauthURLType)
                case .recoveredServerNeedingReauthentication:
                    emptyState.reauthAction(selectedReauthURLType)
                }
            }) {
                Text(emptyState.style.primaryButtonTitle)
            }
            .buttonStyle(.primaryButton)
            reauthURLHint(for: emptyState)
            if canShowErrorDetailsButton(for: emptyState) {
                Button(action: {
                    emptyState.errorDetailsAction()
                }) {
                    Text(L10n.ConnectionError.MoreDetailsSection.title)
                }
                .buttonStyle(.secondaryButton)
            }
            if emptyState.style.showsSecondarySettingsButton, !canShowErrorDetailsButton(for: emptyState) {
                Button(action: {
                    emptyState.settingsAction()
                }) {
                    Text(emptyState.style.secondaryButtonTitle)
                }
                .buttonStyle(.secondaryButton)
            }
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.top)
    }

    @ViewBuilder
    private func reauthURLHint(for emptyState: WebFrontendOverlayState.EmptyStateContent) -> some View {
        if emptyState.style == .unauthenticated, emptyState.availableReauthURLTypes.count > 1 {
            Button {
                showURLPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(selectedReauthURLType.description)
                    Image(systemSymbol: .chevronUpChevronDown)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .confirmationDialog(
                emptyState.style.urlPickerTitle,
                isPresented: $showURLPicker,
                titleVisibility: .visible
            ) {
                ForEach(emptyState.availableReauthURLTypes, id: \.self) { urlType in
                    Button(urlType.description) {
                        selectedReauthURLType = urlType
                    }
                }
            }
        }
    }

    private func registerDismissTap() {
        dismissTapCount += 1
        guard dismissTapCount >= Self.dismissTapThreshold else { return }
        dismissTapCount = 0
        emptyState?.dismissAction()
    }

    // Debug escape hatch while the loader is stuck; empty-state mode already has its own hidden dismiss accessory.
    private func registerLogoDismissTap() {
        guard emptyState == nil, let onLogoDismiss else { return }
        logoDismissTapCount += 1
        guard logoDismissTapCount >= Self.logoDismissTapThreshold else { return }
        logoDismissTapCount = 0
        onLogoDismiss()
    }

    private func selectServer(_ server: Server) {
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.open(server: server)
        }
    }

    private func openSettings() {
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.showSettings()
        }
    }

    private func resolvedLeadingHeaderAccessory(
        for emptyState: WebFrontendOverlayState.EmptyStateContent
    ) -> WebViewEmptyStateStyle.HeaderAccessory {
        if emptyState.style.showsSecondarySettingsButton, canShowErrorDetailsButton(for: emptyState) {
            .settings
        } else {
            emptyState.style.leadingHeaderAccessory
        }
    }

    private func canShowErrorDetailsButton(for emptyState: WebFrontendOverlayState.EmptyStateContent) -> Bool {
        emptyState.style == .disconnected && emptyState.showsErrorDetailsButton
    }
}

private extension HomeAssistantStandByView {
    static func previewServer(
        name: String,
        configuredURLTypes: [ConnectionInfo.URLType],
        activeURLType: ConnectionInfo.URLType
    ) -> Server {
        var info = ServerFixture.withRemoteConnection.info
        info.remoteName = name
        for urlType in [ConnectionInfo.URLType.internal, .external, .remoteUI] {
            info.connection.set(
                address: configuredURLTypes.contains(urlType) ? previewURL(for: urlType) : nil,
                for: urlType
            )
        }
        info.connection.useCloud = configuredURLTypes.contains(.remoteUI)
        info.connection.overrideActiveURLType = activeURLType
        _ = info.connection.evaluateActiveURL()

        return Server(identifier: .init(rawValue: "preview-\(name)"), getter: {
            info
        }, setter: { newInfo in
            info = newInfo
            return true
        })
    }

    static func previewURL(for urlType: ConnectionInfo.URLType) -> URL? {
        switch urlType {
        case .internal:
            URL(string: "http://homeassistant.local:8123")
        case .external:
            URL(string: "https://example.duckdns.org")
        case .remoteUI:
            URL(string: "https://ui.nabu.casa")
        case .none:
            nil
        }
    }

    static func previewEmptyState(
        style: WebViewEmptyStateStyle,
        server: Server,
        showsErrorDetailsButton: Bool = false,
        availableReauthURLTypes: [ConnectionInfo.URLType] = []
    ) -> WebFrontendOverlayState.EmptyStateContent {
        WebFrontendOverlayState.EmptyStateContent(
            style: style,
            server: server,
            showsErrorDetailsButton: showsErrorDetailsButton,
            availableReauthURLTypes: availableReauthURLTypes,
            retryAction: {},
            settingsAction: {},
            errorDetailsAction: {},
            reauthAction: { _ in },
            dismissAction: {}
        )
    }
}

#Preview("Loading Single URL") {
    HomeAssistantStandByView(
        server: HomeAssistantStandByView.previewServer(
            name: "Single URL",
            configuredURLTypes: [.external],
            activeURLType: .external
        ),
        emptyState: nil
    )
}

#Preview("Loading Internal URL") {
    HomeAssistantStandByView(
        server: HomeAssistantStandByView.previewServer(
            name: "Internal URL",
            configuredURLTypes: [.internal, .external, .remoteUI],
            activeURLType: .internal
        ),
        emptyState: nil
    )
}

#Preview("Loading External URL") {
    HomeAssistantStandByView(
        server: HomeAssistantStandByView.previewServer(
            name: "External URL",
            configuredURLTypes: [.internal, .external, .remoteUI],
            activeURLType: .external
        ),
        emptyState: nil
    )
}

#Preview("Loading Remote UI") {
    HomeAssistantStandByView(
        server: HomeAssistantStandByView.previewServer(
            name: "Remote UI",
            configuredURLTypes: [.internal, .external, .remoteUI],
            activeURLType: .remoteUI
        ),
        emptyState: nil
    )
}

#Preview("Loading Multiple Servers") {
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 2)
    // swiftlint:enable prohibit_environment_assignment
    let server = Current.servers.all.first ?? ServerFixture.standard
    return HomeAssistantStandByView(
        server: server,
        emptyState: nil
    )
}

#Preview("Splash Alignment") {
    HomeAssistantStandByView(
        server: ServerFixture.standard,
        emptyState: nil
    )
    .overlay {
        Image("launchScreen-logo")
            .resizable()
            .scaledToFit()
            .frame(
                width: HomeAssistantStandByView.launchScreenLogoSize.width,
                height: HomeAssistantStandByView.launchScreenLogoSize.height
            )
            .opacity(HomeAssistantStandByView.launchScreenLogoPreviewOpacity)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

#Preview("Disconnected") {
    let server = HomeAssistantStandByView.previewServer(
        name: "Disconnected",
        configuredURLTypes: [.external],
        activeURLType: .external
    )
    return HomeAssistantStandByView(
        server: server,
        emptyState: HomeAssistantStandByView.previewEmptyState(style: .disconnected, server: server)
    )
}

#Preview("Disconnected Error Details") {
    let server = HomeAssistantStandByView.previewServer(
        name: "Error Details",
        configuredURLTypes: [.internal, .external],
        activeURLType: .external
    )
    return HomeAssistantStandByView(
        server: server,
        emptyState: HomeAssistantStandByView.previewEmptyState(
            style: .disconnected,
            server: server,
            showsErrorDetailsButton: true
        )
    )
}

#Preview("Unauthenticated") {
    let server = HomeAssistantStandByView.previewServer(
        name: "Needs Login",
        configuredURLTypes: [.internal, .external, .remoteUI],
        activeURLType: .remoteUI
    )
    return HomeAssistantStandByView(
        server: server,
        emptyState: HomeAssistantStandByView.previewEmptyState(
            style: .unauthenticated,
            server: server,
            availableReauthURLTypes: [.remoteUI, .external, .internal]
        )
    )
}

#Preview("Recovered Reauthentication") {
    let server = HomeAssistantStandByView.previewServer(
        name: "Recovered Server",
        configuredURLTypes: [.internal, .external],
        activeURLType: .internal
    )
    return HomeAssistantStandByView(
        server: server,
        emptyState: HomeAssistantStandByView.previewEmptyState(
            style: .recoveredServerNeedingReauthentication,
            server: server,
            availableReauthURLTypes: [.external, .internal]
        )
    )
}
