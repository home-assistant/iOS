import SFSafeSymbols
import Shared
import SwiftUI

struct ConnectionSecurityLevelBlockView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ConnectionSecurityLevelBlockViewModel

    @State private var showSettings = false
    @State private var showHomeNetworkSettings = false
    @State private var showConnectionSecurityPreferences = false

    let server: Server

    private let learnMoreLink = AppConstants.WebURLs.companionAppDocs

    init(server: Server) {
        self._viewModel = .init(wrappedValue: ConnectionSecurityLevelBlockViewModel(server: server))
        self.server = server
    }

    var body: some View {
        NavigationView {
            ScrollView {
                content
            }
            .navigationViewStyle(.stack)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        reload()
                    } label: {
                        Image(systemSymbol: .arrowClockwise)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.requirements.isEmpty {
                        Link(destination: learnMoreLink) {
                            Image(systemSymbol: .questionmark)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
            .onAppear {
                viewModel.loadRequirements()
            }
            .sheet(isPresented: $showSettings) {
                embed(UINavigationController(rootViewController: SettingsViewController()))
                    .onDisappear {
                        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                            .done { webView in
                                dismiss()
                                webView.refresh()
                            }
                    }
            }
            .sheet(isPresented: $showHomeNetworkSettings) {
                homeNetworkView
            }
            .sheet(isPresented: $showConnectionSecurityPreferences) {
                connectionPreferencesView
            }
            .onReceive(NotificationCenter.default.publisher(for: .locationPermissionDidChange)) { notification in
                if let userInfo = notification.userInfo {
                    let state = LocationPermissionState(userInfo: userInfo)
                    switch state {
                    case .notDetermined:
                        Current.Log.info("Location permission not determined")
                    case .denied, .restricted:
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    case .authorizedWhenInUse, .authorizedAlways:
                        // Handle permission change - reload requirements to update UI
                        viewModel.loadRequirements()
                    }
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .lockFill)
                .resizable()
                .foregroundStyle(.haPrimary)
                .scaledToFit()
                .frame(width: 80, height: 80)
            Text(L10n.ConnectionSecurityLevelBlock.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(L10n.ConnectionSecurityLevelBlock.body)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)

            if viewModel.requirements.isEmpty {
                Link(destination: learnMoreLink) {
                    Text(L10n.ConnectionSecurityLevelBlock.Requirement.LearnMore.title)
                }
                .buttonStyle(.secondaryButton)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                    Text(L10n.ConnectionSecurityLevelBlock.Requirement.title)
                        .font(DesignSystem.Font.callout.bold())
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.requirements, id: \.self) { requirement in
                        requirementItem(systemSymbol: requirement.systemSymbol, title: requirement.title)
                            .onTapGesture {
                                switch requirement {
                                case .homeNetworkMissing:
                                    showHomeNetworkSettings = true
                                case .locationPermission:
                                    Current.locationManager.requestLocationPermission()
                                case .notOnHomeNetwork:
                                    Current.Log.info("No action for notOnHomeNetwork requirement")
                                }
                            }
                    }
                }
                .padding(.top)
            }
        }
        .padding(DesignSystem.Spaces.three)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private func requirementItem(systemSymbol: SFSymbol, title: String) -> some View {
        HStack {
            Spacer()
            Image(systemSymbol: systemSymbol)
                .font(DesignSystem.Font.title2)
            Text(title)
                .font(DesignSystem.Font.callout)
            Spacer()
        }
        .foregroundStyle(.haPrimary)
        .frame(minHeight: 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spaces.one)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }

    private var bottomButtons: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Button(action: {
                showSettings = true
            }) {
                Text(L10n.ConnectionSecurityLevelBlock.OpenSettings.title)
            }
            .buttonStyle(.primaryButton)
            Button(action: {
                showConnectionSecurityPreferences = true
            }) {
                Text(L10n.ConnectionSecurityLevelBlock.ChangePreference.title)
            }
            .buttonStyle(.secondaryButton)
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.top)
    }

    private var homeNetworkView: some View {
        NavigationView(content: {
            HomeNetworkInputView(onNext: { ssid in
                guard let ssid else { return }
                server.update { info in
                    info.connection.internalSSIDs = [ssid]
                    showHomeNetworkSettings = false
                }
            })
            .navigationViewStyle(.stack)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        showHomeNetworkSettings = false
                    }
                }
            }
        })
        .onDisappear {
            reload()
        }
    }

    private var connectionPreferencesView: some View {
        NavigationView {
            OnboardingPermissionsNavigationView(
                onboardingServer: server,
                steps: [.localAccess, .updatePreferencesSuccess]
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        showConnectionSecurityPreferences = false
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .onDisappear {
            reload()
        }
    }

    private func reload() {
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise).done { webView in
            webView.refresh()
        }
    }
}

#Preview {
    ConnectionSecurityLevelBlockView(server: ServerFixture.standard)
}
