import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

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
        case .unauthenticated:
            false
        case .recoveredServerNeedingReauthentication:
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

struct WebViewEmptyStateView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @State private var selectedReauthURLType: ConnectionInfo.URLType
    @State private var showURLPicker = false
    @State private var isPerformingPrimaryAction = false
    @State private var errorMessage: String?

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
        ZStack(alignment: .topTrailing) {
            content
            header
        }
        .ignoresSafeArea()
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
        // This is needed alongside with the ignores safe area below because
        // this view is added as a subview to the WebView
        .offset(x: 0, y: safeAreaInsets.top)
    }

    private var content: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            iconView
            Text(style.title)
                .font(.title2)
                .fontWeight(.semibold)
            bodyText
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
        .padding(DesignSystem.Spaces.three)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
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
                .frame(width: 44, height: 44)
        case .settings:
            Button(action: {
                settingsAction?()
            }) {
                Image(systemSymbol: .gearshape)
                    .font(.title3)
                    .foregroundStyle(Color(uiColor: .label))
                    .frame(width: 44, height: 44)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
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
                .foregroundColor(.accentColor)
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
        style == .disconnected && showsErrorDetailsButton
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

#Preview {
    WebViewEmptyStateView(
        style: .disconnected,
        server: ServerFixture.standard
    )
}

final class WebViewEmptyStateWrapperView: UIView {
    private let hostingController: UIHostingController<WebViewEmptyStateView>
    private let server: Server
    private let retryAction: (() -> Void)?
    private let settingsAction: (() -> Void)?
    private let errorDetailsAction: (() -> Void)?
    private let reauthAction: ((ConnectionInfo.URLType) -> Void)?
    private let recoveredServerReauthAction: (
        (ConnectionInfo.URLType, @escaping (Swift.Result<Void, Error>) -> Void)
            -> Void
    )?
    private let serverSelectionAction: ((Server) -> Void)?
    private let dismissAction: (() -> Void)?
    private(set) var style: WebViewEmptyStateStyle
    private(set) var showsErrorDetailsButton: Bool

    init(
        style: WebViewEmptyStateStyle = .disconnected,
        server: Server,
        showsErrorDetailsButton: Bool = false,
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
        self.retryAction = retryAction
        self.settingsAction = settingsAction
        self.errorDetailsAction = errorDetailsAction
        self.reauthAction = reauthAction
        self.recoveredServerReauthAction = recoveredServerReauthAction
        self.serverSelectionAction = serverSelectionAction
        self.dismissAction = dismissAction
        let swiftUIView = WebViewEmptyStateView(
            style: style,
            server: server,
            showsErrorDetailsButton: showsErrorDetailsButton,
            availableReauthURLTypes: Self.availableReauthURLTypes(for: server),
            retryAction: retryAction,
            settingsAction: settingsAction,
            errorDetailsAction: errorDetailsAction,
            reauthAction: reauthAction,
            recoveredServerReauthAction: recoveredServerReauthAction,
            serverSelectionAction: serverSelectionAction,
            dismissAction: dismissAction
        )
        self.hostingController = UIHostingController(rootView: swiftUIView)
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        backgroundColor = .clear
    }

    func update(style: WebViewEmptyStateStyle, showsErrorDetailsButton: Bool) {
        guard self.style != style || self.showsErrorDetailsButton != showsErrorDetailsButton else { return }
        self.style = style
        self.showsErrorDetailsButton = showsErrorDetailsButton
        hostingController.rootView = WebViewEmptyStateView(
            style: style,
            server: server,
            showsErrorDetailsButton: showsErrorDetailsButton,
            availableReauthURLTypes: Self.availableReauthURLTypes(for: server),
            retryAction: retryAction,
            settingsAction: settingsAction,
            errorDetailsAction: errorDetailsAction,
            reauthAction: reauthAction,
            recoveredServerReauthAction: recoveredServerReauthAction,
            serverSelectionAction: serverSelectionAction,
            dismissAction: dismissAction
        )
    }

    /// Returns available URL types for re-authentication, ordered by preference: remote UI > external > internal.
    private static func availableReauthURLTypes(for server: Server) -> [ConnectionInfo.URLType] {
        let preferenceOrder: [ConnectionInfo.URLType] = [.remoteUI, .external, .internal]
        return preferenceOrder.filter { server.info.connection.address(for: $0) != nil }
    }
}
