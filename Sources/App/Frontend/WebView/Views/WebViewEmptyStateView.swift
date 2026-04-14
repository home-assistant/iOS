import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

enum WebViewEmptyStateStyle: Equatable {
    case disconnected
    case unauthenticated

    var title: String {
        switch self {
        case .disconnected:
            L10n.WebView.EmptyState.title
        case .unauthenticated:
            L10n.Unauthenticated.Message.title
        }
    }

    var body: String {
        switch self {
        case .disconnected:
            L10n.WebView.EmptyState.body
        case .unauthenticated:
            L10n.Unauthenticated.Message.body
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .disconnected:
            L10n.WebView.EmptyState.retryButton
        case .unauthenticated:
            L10n.WebView.EmptyState.reauthenticateButton
        }
    }

    var secondaryButtonTitle: String {
        switch self {
        case .disconnected, .unauthenticated:
            L10n.WebView.EmptyState.openSettingsButton
        }
    }
}

struct WebViewEmptyStateView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @State private var selectedReauthURLType: ConnectionInfo.URLType
    @State private var showURLPicker = false

    let style: WebViewEmptyStateStyle
    let server: Server
    let availableReauthURLTypes: [ConnectionInfo.URLType]
    let retryAction: (() -> Void)?
    let settingsAction: (() -> Void)?
    let reauthAction: ((ConnectionInfo.URLType) -> Void)?
    let dismissAction: (() -> Void)?

    init(
        style: WebViewEmptyStateStyle,
        server: Server,
        availableReauthURLTypes: [ConnectionInfo.URLType] = [],
        retryAction: (() -> Void)? = nil,
        settingsAction: (() -> Void)? = nil,
        reauthAction: ((ConnectionInfo.URLType) -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.style = style
        self.server = server
        self.availableReauthURLTypes = availableReauthURLTypes
        self._selectedReauthURLType = State(initialValue: availableReauthURLTypes.first ?? .external)
        self.retryAction = retryAction
        self.settingsAction = settingsAction
        self.reauthAction = reauthAction
        self.dismissAction = dismissAction
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            header
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        Group {
            serverSelection
            ModalCloseButton {
                dismissAction?()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        // This is needed alongside with the ignores safe area below because
        // this view is added as a subview to the WebView
        .offset(x: 0, y: safeAreaInsets.top)
    }

    private var content: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            Text(style.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(style.body)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)
            VStack(spacing: DesignSystem.Spaces.one) {
                primaryButton
                    .buttonStyle(.primaryButton)
                reauthURLHint
                secondaryButton
                    .buttonStyle(.secondaryButton)
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
        if Current.servers.all.count > 1 {
            HStack {
                Spacer()
                ServerPickerView(server: server)
                #if targetEnvironment(macCatalyst)
                    .padding()
                #endif
                    // Using .secondarySystemBackground to visually distinguish the server selection view
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Capsule())
                Spacer()
            }
        }
    }

    private var primaryButton: some View {
        Button(action: {
            switch style {
            case .disconnected:
                retryAction?()
            case .unauthenticated:
                reauthAction?(selectedReauthURLType)
            }
        }) {
            Text(style.primaryButtonTitle)
        }
    }

    @ViewBuilder
    private var reauthURLHint: some View {
        if style == .unauthenticated, availableReauthURLTypes.count > 1 {
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
                L10n.WebView.EmptyState.reauthenticateButton,
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
            case .disconnected, .unauthenticated:
                settingsAction?()
            }
        }) {
            Text(style.secondaryButtonTitle)
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
    private let reauthAction: ((ConnectionInfo.URLType) -> Void)?
    private let dismissAction: (() -> Void)?
    private(set) var style: WebViewEmptyStateStyle

    init(
        style: WebViewEmptyStateStyle = .disconnected,
        server: Server,
        retryAction: (() -> Void)? = nil,
        settingsAction: (() -> Void)? = nil,
        reauthAction: ((ConnectionInfo.URLType) -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.style = style
        self.server = server
        self.retryAction = retryAction
        self.settingsAction = settingsAction
        self.reauthAction = reauthAction
        self.dismissAction = dismissAction
        let swiftUIView = WebViewEmptyStateView(
            style: style,
            server: server,
            availableReauthURLTypes: Self.availableReauthURLTypes(for: server),
            retryAction: retryAction,
            settingsAction: settingsAction,
            reauthAction: reauthAction,
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

    func updateStyle(_ style: WebViewEmptyStateStyle) {
        guard self.style != style else { return }
        self.style = style
        hostingController.rootView = WebViewEmptyStateView(
            style: style,
            server: server,
            availableReauthURLTypes: Self.availableReauthURLTypes(for: server),
            retryAction: retryAction,
            settingsAction: settingsAction,
            reauthAction: reauthAction,
            dismissAction: dismissAction
        )
    }

    /// Returns available URL types for re-authentication, ordered by preference: remote UI > external > internal.
    private static func availableReauthURLTypes(for server: Server) -> [ConnectionInfo.URLType] {
        let preferenceOrder: [ConnectionInfo.URLType] = [.remoteUI, .external, .internal]
        return preferenceOrder.filter { server.info.connection.address(for: $0) != nil }
    }
}
