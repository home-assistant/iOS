import SFSafeSymbols
import Shared
import SwiftUI

/// Bottom action stack of the connection/re-authentication empty state, shared by
/// `HomeAssistantStandByView` and `WebViewEmptyStateView`: primary action, re-authentication URL hint
/// and either the error details or the secondary settings button.
struct WebViewEmptyStateActionButtons: View {
    let style: WebViewEmptyStateStyle
    let availableReauthURLTypes: [ConnectionInfo.URLType]
    let showsErrorDetailsButton: Bool
    let retryAction: () -> Void
    let settingsAction: () -> Void
    let errorDetailsAction: () -> Void
    let reauthAction: (ConnectionInfo.URLType) -> Void
    /// Recovered-server re-authentication reports its outcome back, so the primary button can show
    /// progress while the login flow runs and surface a failure as an alert. Without it the recovered
    /// style falls back to `reauthAction`.
    let recoveredServerReauthAction: ((
        ConnectionInfo.URLType,
        @escaping (Swift.Result<Void, Error>) -> Void
    ) -> Void)?

    @State private var selectedReauthURLType: ConnectionInfo.URLType
    @State private var showURLPicker = false
    @State private var isPerformingPrimaryAction = false
    @State private var errorMessage: String?

    init(
        style: WebViewEmptyStateStyle,
        availableReauthURLTypes: [ConnectionInfo.URLType],
        showsErrorDetailsButton: Bool = false,
        retryAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void,
        errorDetailsAction: @escaping () -> Void,
        reauthAction: @escaping (ConnectionInfo.URLType) -> Void,
        recoveredServerReauthAction: ((
            ConnectionInfo.URLType,
            @escaping (Swift.Result<Void, Error>) -> Void
        ) -> Void)? = nil
    ) {
        self.style = style
        self.availableReauthURLTypes = availableReauthURLTypes
        self.showsErrorDetailsButton = showsErrorDetailsButton
        self.retryAction = retryAction
        self.settingsAction = settingsAction
        self.errorDetailsAction = errorDetailsAction
        self.reauthAction = reauthAction
        self.recoveredServerReauthAction = recoveredServerReauthAction
        self._selectedReauthURLType = State(initialValue: availableReauthURLTypes.first ?? .external)
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            styledPrimaryButton
            if showsReauthURLPicker {
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
            if showsErrorDetailsButton {
                Button(action: errorDetailsAction) {
                    Text(L10n.ConnectionError.MoreDetailsSection.title)
                }
                .buttonStyle(.secondaryButton)
            }
            if style.showsSecondarySettingsButton, !showsErrorDetailsButton {
                Button(action: settingsAction) {
                    Text(style.secondaryButtonTitle)
                }
                .buttonStyle(.secondaryButton)
            }
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.top)
        .onChange(of: availableReauthURLTypes) { newValue in
            selectedReauthURLType = newValue.first ?? .external
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
    }

    /// Re-authentication is on the user, not on the app retrying, so it gets the warning-colored button
    /// (the frontend's `ha-button variant="warning"`) to read as "action required".
    @ViewBuilder
    private var styledPrimaryButton: some View {
        if style.primaryActionRequiresAttention {
            primaryButton
                .buttonStyle(.warningButton)
        } else {
            primaryButton
                .buttonStyle(.primaryButton)
        }
    }

    private var primaryButton: some View {
        Button(action: performPrimaryAction) {
            if isPerformingPrimaryAction {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
            } else {
                Text(style.primaryButtonTitle)
            }
        }
        .disabled(isPerformingPrimaryAction)
    }

    private var showsReauthURLPicker: Bool {
        guard style == .unauthenticated || style == .loggedOut
            || style == .recoveredServerNeedingReauthentication else { return false }
        return availableReauthURLTypes.count > 1
    }

    private func performPrimaryAction() {
        switch style {
        case .disconnected, .inFlight:
            retryAction()
        case .unauthenticated, .loggedOut:
            reauthAction(selectedReauthURLType)
        case .recoveredServerNeedingReauthentication:
            if recoveredServerReauthAction == nil {
                reauthAction(selectedReauthURLType)
            } else {
                beginRecoveredServerReauthentication()
            }
        }
    }

    private func beginRecoveredServerReauthentication() {
        guard !isPerformingPrimaryAction, let recoveredServerReauthAction else { return }
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

#Preview("Disconnected") {
    WebViewEmptyStateActionButtons(
        style: .disconnected,
        availableReauthURLTypes: [],
        retryAction: {},
        settingsAction: {},
        errorDetailsAction: {},
        reauthAction: { _ in }
    )
}

#Preview("Disconnected With Error Details") {
    WebViewEmptyStateActionButtons(
        style: .disconnected,
        availableReauthURLTypes: [],
        showsErrorDetailsButton: true,
        retryAction: {},
        settingsAction: {},
        errorDetailsAction: {},
        reauthAction: { _ in }
    )
}

#Preview("Unauthenticated Multiple URLs") {
    WebViewEmptyStateActionButtons(
        style: .unauthenticated,
        availableReauthURLTypes: [.remoteUI, .external, .internal],
        retryAction: {},
        settingsAction: {},
        errorDetailsAction: {},
        reauthAction: { _ in }
    )
}

#Preview("Recovered Reauthentication Failure") {
    WebViewEmptyStateActionButtons(
        style: .recoveredServerNeedingReauthentication,
        availableReauthURLTypes: [.remoteUI, .external],
        retryAction: {},
        settingsAction: {},
        errorDetailsAction: {},
        reauthAction: { _ in },
        recoveredServerReauthAction: { _, completion in
            completion(.failure(NSError(
                domain: "Preview",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Reauthentication failed."]
            )))
        }
    )
}
