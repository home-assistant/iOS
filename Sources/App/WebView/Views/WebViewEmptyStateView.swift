import Shared
import SwiftUI
import UIKit

struct WebViewEmptyStateView: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    @State private var showCloseButton = false
    let retryAction: (() -> Void)?
    let settingsAction: (() -> Void)?
    let dismissAction: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: Spaces.two) {
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
                    .padding(.horizontal, Spaces.two)
                VStack(spacing: Spaces.one) {
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
                .padding(.horizontal, Spaces.two)
                .padding(.top)
            }
            .padding(Spaces.three)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
            CloseButton(size: .medium) {
                dismissAction?()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
            // This is needed alongside with the ignores safe area below because
            // this view is added as a subview to the WebView
            .offset(x: 0, y: safeAreaInsets.top)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    WebViewEmptyStateView {} settingsAction: {} dismissAction: {}
}

final class WebViewEmptyStateWrapperView: UIView {
    private let hostingController: UIHostingController<WebViewEmptyStateView>

    init(retryAction: (() -> Void)? = nil, settingsAction: (() -> Void)? = nil, dismissAction: (() -> Void)? = nil) {
        let swiftUIView = WebViewEmptyStateView(
            retryAction: retryAction,
            settingsAction: settingsAction,
            dismissAction: dismissAction
        )
        self.hostingController = UIHostingController(rootView: swiftUIView)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.hostingController = UIHostingController(rootView: WebViewEmptyStateView(
            retryAction: nil,
            settingsAction: nil,
            dismissAction: nil
        ))
        super.init(coder: coder)
        setup()
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

private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        (UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets ?? .zero).insets
    }
}

private extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}

private extension UIEdgeInsets {
    var insets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}
