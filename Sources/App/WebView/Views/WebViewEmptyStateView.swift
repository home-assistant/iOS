import Shared
import SwiftUI
import UIKit

struct WebViewEmptyStateView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    @State private var showCloseButton = false
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
            CloseButton(size: .medium, forceIconOnly: true) {
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
            Text(L10n.WebView.EmptyState.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(L10n.WebView.EmptyState.body)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)
            VStack(spacing: DesignSystem.Spaces.one) {
                Button(action: {
                    retryAction?()
                }) {
                    Text(L10n.WebView.EmptyState.retryButton)
                }
                .buttonStyle(.primaryButton)
                Button(action: {
                    settingsAction?()
                }) {
                    Text(L10n.WebView.EmptyState.openSettingsButton)
                }
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
}

#Preview {
    WebViewEmptyStateView(server: ServerFixture.standard) {} settingsAction: {} dismissAction: {}
}

final class WebViewEmptyStateWrapperView: UIView {
    private let hostingController: UIHostingController<WebViewEmptyStateView>
    private let server: Server

    init(
        server: Server,
        retryAction: (() -> Void)? = nil,
        settingsAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.server = server
        let swiftUIView = WebViewEmptyStateView(
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
}
