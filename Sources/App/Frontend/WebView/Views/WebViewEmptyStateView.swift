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
            L10n.WebView.EmptyState.openSettingsButton
        }
    }

    var secondaryButtonTitle: String {
        switch self {
        case .disconnected:
            L10n.WebView.EmptyState.openSettingsButton
        case .unauthenticated:
            L10n.WebView.EmptyState.retryButton
        }
    }
}

struct WebViewEmptyStateView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    let style: WebViewEmptyStateStyle
    let server: Server
    let retryAction: (() -> Void)?
    let settingsAction: (() -> Void)?
    let dismissAction: (() -> Void)?

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
                settingsAction?()
            }
        }) {
            Text(style.primaryButtonTitle)
        }
    }

    private var secondaryButton: some View {
        Button(action: {
            switch style {
            case .disconnected:
                settingsAction?()
            case .unauthenticated:
                retryAction?()
            }
        }) {
            Text(style.secondaryButtonTitle)
        }
    }
}

#Preview {
    WebViewEmptyStateView(style: .disconnected, server: ServerFixture.standard) {} settingsAction: {} dismissAction: {}
}

final class WebViewEmptyStateWrapperView: UIView {
    private let hostingController: UIHostingController<WebViewEmptyStateView>
    private let server: Server
    private let retryAction: (() -> Void)?
    private let settingsAction: (() -> Void)?
    private let dismissAction: (() -> Void)?
    private(set) var style: WebViewEmptyStateStyle

    init(
        style: WebViewEmptyStateStyle = .disconnected,
        server: Server,
        retryAction: (() -> Void)? = nil,
        settingsAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.style = style
        self.server = server
        self.retryAction = retryAction
        self.settingsAction = settingsAction
        self.dismissAction = dismissAction
        let swiftUIView = WebViewEmptyStateView(
            style: style,
            server: server,
            retryAction: retryAction,
            settingsAction: settingsAction,
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
            retryAction: retryAction,
            settingsAction: settingsAction,
            dismissAction: dismissAction
        )
    }
}
