import SFSafeSymbols
import Shared
import SwiftUI

struct WebViewEmptyStateView: View {
    @State private var selectedReauthURLType: ConnectionInfo.URLType
    @State private var showURLPicker = false
    @State private var isPerformingPrimaryAction = false
    @State private var errorMessage: String?

    private let headerAccessorySize = CGSize(width: 44, height: 44)

    let style: WebViewEmptyStateStyle
    let server: Server
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
        self.showsErrorDetailsButton = showsErrorDetailsButton
        self.availableReauthURLTypes = availableReauthURLTypes
        self._selectedReauthURLType = State(initialValue: availableReauthURLTypes.first ?? .external)
        self.retryAction = retryAction
        self.settingsAction = settingsAction
        self.errorDetailsAction = errorDetailsAction
        self.reauthAction = reauthAction
        self.recoveredServerReauthAction = recoveredServerReauthAction
        self.serverSelectionAction = serverSelectionAction
        self.dismissAction = dismissAction
    }

    var body: some View {
        content
            .safeAreaInset(edge: .top, content: {
                header
            })
            .safeAreaInset(edge: .bottom, content: {
                actionButtons
            })
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
    }

    private var header: some View {
        HStack {
            headerAccessory(resolvedLeadingHeaderAccessory)

            Spacer()
            serverSelection
            Spacer()

            headerAccessory(style.trailingHeaderAccessory)
        }
        .padding()
    }

    private var content: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            iconView
            VStack(spacing: DesignSystem.Spaces.one) {
                Text(style.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                bodyText
            }
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spaces.three)
        .padding(.top, DesignSystem.Spaces.five)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            primaryButton
                .buttonStyle(.primaryButton)
            reauthURLHint
            if canShowErrorDetailsButton {
                errorDetailsButton
                    .buttonStyle(.secondaryButton)
            }
            if style.showsSecondarySettingsButton, !canShowErrorDetailsButton {
                secondaryButton
                    .buttonStyle(.secondaryButton)
            }
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.top)
    }

    @ViewBuilder
    private var serverSelection: some View {
        if style.showsServerPicker, Current.servers.all.count > 1 {
            ServerPickerView(server: server, onSelect: serverSelectionAction)
            #if targetEnvironment(macCatalyst)
                .padding()
            #endif
                // Using .secondarySystemBackground to visually distinguish the server selection view
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func headerAccessory(_ accessory: WebViewEmptyStateStyle.HeaderAccessory) -> some View {
        switch accessory {
        case .none:
            Color.clear
                .frame(width: headerAccessorySize.width, height: headerAccessorySize.height)
        case .settings:
            Button(action: {
                settingsAction?()
            }) {
                Image(systemSymbol: .gearshape)
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
                    .frame(width: headerAccessorySize.width, height: headerAccessorySize.height)
            }
            .accessibilityLabel(L10n.WebView.EmptyState.openSettingsButton)
        case .close:
            ModalCloseButton {
                dismissAction?()
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch style {
        case .disconnected, .unauthenticated:
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
        case .recoveredServerNeedingReauthentication:
            Image(systemSymbol: .key)
                .font(.system(size: 56))
                .foregroundStyle(Color.haPrimary)
        }
    }

    @ViewBuilder
    private var bodyText: some View {
        switch style {
        case .disconnected, .unauthenticated:
            Text(style.body)
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

    private var primaryButton: some View {
        Button(action: {
            switch style {
            case .disconnected:
                retryAction?()
            case .unauthenticated:
                reauthAction?(selectedReauthURLType)
            case .recoveredServerNeedingReauthentication:
                beginRecoveredServerReauthentication()
            }
        }) {
            if style == .recoveredServerNeedingReauthentication, isPerformingPrimaryAction {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
            } else {
                Text(style.primaryButtonTitle)
            }
        }
        .disabled(style == .recoveredServerNeedingReauthentication && isPerformingPrimaryAction)
    }

    @ViewBuilder
    private var reauthURLHint: some View {
        if style == .unauthenticated || style == .recoveredServerNeedingReauthentication,
           availableReauthURLTypes.count > 1 {
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
                style.urlPickerTitle,
                isPresented: $showURLPicker,
                titleVisibility: .visible
            ) {
                ForEach(availableReauthURLTypes, id: \.self) { urlType in
                    Button(urlType.description) {
                        selectedReauthURLType = urlType
                    }
                }
            }
        }
    }

    private var secondaryButton: some View {
        Button(action: {
            switch style {
            case .disconnected, .unauthenticated, .recoveredServerNeedingReauthentication:
                settingsAction?()
            }
        }) {
            Text(style.secondaryButtonTitle)
        }
    }

    private var canShowErrorDetailsButton: Bool {
        style == .disconnected && showsErrorDetailsButton && errorDetailsAction != nil
    }

    private var resolvedLeadingHeaderAccessory: WebViewEmptyStateStyle.HeaderAccessory {
        if style.showsSecondarySettingsButton, canShowErrorDetailsButton {
            .settings
        } else {
            style.leadingHeaderAccessory
        }
    }

    private var errorDetailsButton: some View {
        Button(action: {
            errorDetailsAction?()
        }) {
            Text(L10n.ConnectionError.MoreDetailsSection.title)
        }
    }

    private func beginRecoveredServerReauthentication() {
        guard !isPerformingPrimaryAction else { return }
        guard let recoveredServerReauthAction else { return }
        isPerformingPrimaryAction = true
        errorMessage = nil

        recoveredServerReauthAction(selectedReauthURLType) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break
                case let .failure(error):
                    isPerformingPrimaryAction = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
