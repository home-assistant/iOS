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

    @ViewBuilder
    private var configureButton: some View {
        Button(L10n.Connection.Permission.InternalUrl.buttonConfigure) {
            Current.Log.info("Tapped configure local access button in NoActiveURLView")
            configure()
        }
        .buttonStyle(.primaryButton)
        .padding(.top)
        Button("I trust this network, remind me tomorrow") {
            Current.Log.info("Tapped configure local access button in NoActiveURLView")
            configure()
        }
        .buttonStyle(.secondaryButton)
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
            Spacer()
            CloseButton {
                Current.Log.info("Dismissed NoActiveURLView")
                dismiss()
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
        Text("Are you home?")
            .font(.title.bold())
            .padding(.top)
        Text("The app is trying to connect to a local network but is unable to know if you are at home.")
            .font(.body)
            .multilineTextAlignment(.center)

        VStack(spacing: Spaces.two) {
            permissionRow(permissionProvided: false, title: "Your Wifi network name", subtitle: "e.g. MyHomeWifi")
            permissionRow(permissionProvided: true, title: "Location access", subtitle: "To check if you are connected to the same Wifi network as your home, Apple requires location access. You are still in control if you want to share this information with Home Assistant itself.")
        }
        .padding()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top)
    }

    private func permissionRow(permissionProvided: Bool, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: Spaces.two) {
            Image(systemSymbol: permissionProvided ? .checkmarkCircleFill : .circleDashed)
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundStyle(permissionProvided ? Color.asset(Asset.Colors.haPrimary) : .yellow)
            VStack {
                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 28)
                Text(subtitle)
                    .font(.footnote.weight(.light))
                    .frame(maxWidth: .infinity, alignment: .leading)

            }
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
