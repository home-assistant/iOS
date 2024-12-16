import SFSafeSymbols
import Shared
import SwiftUI

struct NoActiveURLView: View {
    @Environment(\.dismiss) private var dismiss
    let server: Server

    @State private var showIgnoreConfirmation = false

    var body: some View {
        ScrollView {
            VStack {
                VStack {
                    header
                    Image(imageAsset: Asset.SharedAssets.logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 140)

                    textBlock
                    configureButton
                }
                .padding()
                footer
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onDisappear {
            Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                .done { webViewController in
                    webViewController.overlayAppController = nil
                }
        }
        .alert(L10n.Connection.Permission.InternalUrl.Ignore.Alert.title, isPresented: $showIgnoreConfirmation) {
            Button(L10n.yesLabel, role: .destructive) {
                ignore()
            }
        }
    }

    private func ignore() {
        server.update { info in
            info.connection.alwaysFallbackToInternalURL = true

            Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                .done { webViewController in
                    dismiss()
                    webViewController.reload()
                }
        }
    }

    private var configureButton: some View {
        Button(L10n.Connection.Permission.InternalUrl.buttonConfigure) {
            Current.Log.info("Tapped configure local access button in NoActiveURLView")
            configure()
        }
        .buttonStyle(.primaryButton)
        .padding(.vertical)
    }

    private func configure() {
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
            .done { webViewController in
                let controller = ConnectionURLViewController(
                    server: server,
                    urlType: .internal,
                    row: .init(tag: "")
                )
                let navController = UINavigationController(rootViewController: controller)
                controller.onDismissCallback = { _ in
                    navController.dismiss(animated: true) {
                        webViewController.reload()
                    }
                }
                webViewController.presentOverlayController(controller: navController, animated: true)
            }
    }

    private var header: some View {
        HStack {
            Button {
                Current.Log.info("Tapped settings button in NoActiveURLView")
                showSettings()
            } label: {
                Image(systemSymbol: .gear)
            }
            .font(.title2)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            Spacer()
            Button {
                Current.Log.info("Dismissed NoActiveURLView")
                dismiss()
            } label: {
                Image(systemSymbol: .xmark)
            }
        }
    }

    private func showSettings() {
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
            .done { webViewController in
                webViewController.showSettingsViewController()
            }
    }

    @ViewBuilder
    private var textBlock: some View {
        Text(L10n.Connection.Permission.InternalUrl.title)
            .font(.title.bold())
            .padding(.vertical)
        VStack(spacing: Spaces.two) {
            Group {
                makeRow(icon: .map, text: L10n.Connection.Permission.InternalUrl.body1)
                makeRow(icon: .wifi, text: L10n.Connection.Permission.InternalUrl.body2)
                makeRow(icon: .lock, text: L10n.Connection.Permission.InternalUrl.body3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func makeRow(icon: SFSymbol, text: String) -> some View {
        HStack(spacing: Spaces.two) {
            VStack {
                Image(systemSymbol: icon)
                    .font(.title)
                    .foregroundStyle(Color(uiColor: Asset.Colors.haPrimary.color))
            }
            .frame(width: 30, height: 30)
            Text(text)
                .font(.body)
        }
    }

    private var footer: some View {
        VStack {
            Text(
                L10n.Connection.Permission.InternalUrl.footer
            )
            .font(.footnote)
            .multilineTextAlignment(.center)
            Button(L10n.Connection.Permission.InternalUrl.buttonIgnore) {
                showIgnoreConfirmation = true
            }
            .buttonStyle(.criticalButton)
            .padding(.vertical)
        }
        .padding()
        .padding(.vertical)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            NoActiveURLView(server: ServerFixture.standard)
        }
}

final class NoActiveURLViewController: UIHostingController<NoActiveURLView> {
    init(server: Server) {
        super.init(rootView: NoActiveURLView(server: server))
    }

    @available(*, unavailable)
    @MainActor @preconcurrency dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
