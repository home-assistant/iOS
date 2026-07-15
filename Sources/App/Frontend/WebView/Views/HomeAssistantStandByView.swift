import SFSafeSymbols
import Shared
import SwiftUI

struct HomeAssistantStandByView: View {
    static let dismissTapThreshold = 5

    private static let headerAccessorySize = CGSize(width: 44, height: 44)
    private static let loadingLogoSize = CGSize(width: 115, height: 115)
    private static let emptyStateLogoSize = CGSize(width: 80, height: 80)
    private static let reauthenticationIconSize: CGFloat = 56
    fileprivate static let launchScreenLogoSize = CGSize(width: 147, height: 174)
    fileprivate static let launchScreenLogoPreviewOpacity = 0.55

    let server: Server
    let emptyState: WebFrontendOverlayState.EmptyStateContent?
    let isLoading: Bool

    @State private var selectedReauthURLType: ConnectionInfo.URLType
    @State private var showURLPicker = false
    @State private var isPerformingPrimaryAction = false
    @State private var errorMessage: String?
    @State private var dismissTapCount = 0
    @State private var showsEmptyStateContent = false
    @State private var hasAppeared = false

    init(
        server: Server,
        emptyState: WebFrontendOverlayState.EmptyStateContent?,
        isLoading: Bool = false
    ) {
        self.server = server
        self.emptyState = emptyState
        self.isLoading = isLoading
        self._selectedReauthURLType = State(initialValue: emptyState?.availableReauthURLTypes.first ?? .external)
    }

    var body: some View {
        let showsEmptyState = emptyState != nil
        let contentOpacity = showsEmptyStateContent ? 1.0 : 0.0

        ZStack {
            Color(uiColor: .systemBackground)
                .opacity(contentOpacity)
                .ignoresSafeArea()
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(showsEmptyState ? 0 : 1)
                .ignoresSafeArea()
            VStack(spacing: showsEmptyState ? DesignSystem.Spaces.three : DesignSystem.Spaces.five) {
                iconView
                    .frame(
                        width: showsEmptyState ? Self.emptyStateLogoSize.width : Self.loadingLogoSize.width,
                        height: showsEmptyState ? Self.emptyStateLogoSize.height : Self.loadingLogoSize.height
                    )
                if let emptyState {
                    VStack(spacing: DesignSystem.Spaces.one) {
                        Text(emptyState.style.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        bodyText(for: emptyState)
                    }
                    .opacity(contentOpacity)
                    .transition(.opacity)
                    Spacer()
                } else {
                    HAProgressView()
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.three)
            .padding(.top, showsEmptyState ? DesignSystem.Spaces.five : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showsEmptyState ? .top : .center)
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
        .opacity(hasAppeared ? 1 : 0)
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
    }

    @ViewBuilder
    private var iconView: some View {
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
                    break
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

    private func selectServer(_ server: Server) {
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.open(server: server)
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

#Preview("Loading") {
    HomeAssistantStandByView(
        server: ServerFixture.standard,
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

#Preview("Empty State") {
    HomeAssistantStandByView(
        server: ServerFixture.standard,
        emptyState: WebFrontendOverlayState.EmptyStateContent(
            style: .disconnected,
            server: ServerFixture.standard,
            showsErrorDetailsButton: false,
            availableReauthURLTypes: [],
            retryAction: {},
            settingsAction: {},
            errorDetailsAction: {},
            reauthAction: { _ in },
            dismissAction: {}
        )
    )
}
