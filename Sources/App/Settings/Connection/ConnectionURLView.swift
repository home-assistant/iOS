import CoreLocation
import Foundation
import PromiseKit
import Shared
import SwiftUI

// Migrated to SwiftUI using Copilot agent https://github.com/home-assistant/iOS/pull/3956
struct ConnectionURLView: View {
    let urlType: ConnectionInfo.URLType
    let onDismiss: () -> Void

    @StateObject private var viewModel: ConnectionURLViewModel

    init(server: Server, urlType: ConnectionInfo.URLType, onDismiss: @escaping () -> Void) {
        self.urlType = urlType
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: ConnectionURLViewModel(server: server, urlType: urlType))
    }

    var body: some View {
        Form {
            cloudToggleSection
            urlSection
            ssidSection
            hardwareAddressSection
            localPushSection
        }
        .navigationTitle(urlType.description)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                saveButton
            }
        }
        .alert(L10n.Settings.ConnectionSection.ValidateError.title, isPresented: $viewModel.showError) {
            if viewModel.canCommitAnyway {
                Button(L10n.Settings.ConnectionSection.ValidateError.useAnyway) {
                    viewModel.save(onSuccess: onDismiss)
                }
            }
            Button(L10n.Settings.ConnectionSection.ValidateError.editUrl, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Cloud Toggle Section

    /// Shows cloud toggle only if the URL type can be overridden by cloud
    /// (typically external URLs) and the server has cloud capabilities enabled.
    @ViewBuilder
    private var cloudToggleSection: some View {
        if urlType.isAffectedByCloud, viewModel.server.info.connection.canUseCloud {
            Section {
                Toggle(L10n.Settings.ConnectionSection.HomeAssistantCloud.title, isOn: $viewModel.useCloud)
            }
        }
    }

    // MARK: - URL Section

    @ViewBuilder
    private var urlSection: some View {
        Section("URL") {
            urlInputOrCloudMessage
        }
    }

    /// Shows URL text field if cloud is disabled, URL type is not affected by cloud,
    /// or server doesn't support cloud. Otherwise, shows informational text that cloud overrides the URL.
    @ViewBuilder
    private var urlInputOrCloudMessage: some View {
        if !viewModel.useCloud || !urlType.isAffectedByCloud || !viewModel.server.info.connection.canUseCloud {
            urlTextField
            securityWarning
        } else {
            Text(L10n.Settings.ConnectionSection.cloudOverridesExternal)
                .foregroundColor(.secondary)
                .font(.footnote)
        }
    }

    private var urlTextField: some View {
        TextField(viewModel.placeholder, text: $viewModel.url)
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocapitalization(.none)
            .autocorrectionDisabled()
    }

    /// Security warning displayed for external URLs that don't use HTTPS.
    @ViewBuilder
    private var securityWarning: some View {
        if shouldShowSecurityWarning {
            HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                Image(systemSymbol: .exclamationmarkShieldFill)
                    .foregroundColor(.orange)
                    .imageScale(.medium)
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(L10n.SettingsDetails.Http.Warning.title)
                        .font(DesignSystem.Font.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(L10n.SettingsDetails.Http.Warning.message)
                        .font(DesignSystem.Font.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, DesignSystem.Spaces.one)
        }
    }

    // MARK: - SSID Section

    @ViewBuilder
    private var ssidSection: some View {
        if urlType.isAffectedBySSID {
            locationPermissionSection
            ssidListSection
        }
    }

    private var ssidListSection: some View {
        Section {
            ForEach(viewModel.ssids.indices, id: \.self) { index in
                HStack {
                    TextField(
                        L10n.Settings.ConnectionSection.InternalUrlSsids.placeholder,
                        text: $viewModel.ssids[index]
                    )
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    Button(action: { viewModel.removeSSID(at: index) }) {
                        Image(systemSymbol: .minusCircleFill)
                            .foregroundColor(.red)
                    }
                }
            }
            .onDelete { indexSet in
                viewModel.removeSSIDs(at: indexSet)
            }

            Button(action: viewModel.addSSID) {
                Text(L10n.Settings.ConnectionSection.InternalUrlSsids.addNewSsid)
            }
        } header: {
            Text(L10n.Settings.ConnectionSection.InternalUrlSsids.header)
        } footer: {
            Text(L10n.Settings.ConnectionSection.InternalUrlSsids.footer)
        }
    }

    // MARK: - Hardware Address Section

    @ViewBuilder
    private var hardwareAddressSection: some View {
        if urlType.isAffectedByHardwareAddress {
            Section {
                ForEach(viewModel.hardwareAddresses.indices, id: \.self) { index in
                    HStack {
                        TextField("aa:bb:cc:dd:ee:ff", text: $viewModel.hardwareAddresses[index])
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        Button(action: { viewModel.removeHardwareAddress(at: index) }) {
                            Image(systemSymbol: .minusCircleFill)
                                .foregroundColor(.red)
                        }
                    }
                }
                .onDelete { indexSet in
                    viewModel.removeHardwareAddresses(at: indexSet)
                }

                Button(action: viewModel.addHardwareAddress) {
                    Text(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.addNewSsid)
                }
            } header: {
                Text(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.header)
            } footer: {
                Text(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.footer)
            }
        }
    }

    // MARK: - Local Push Section

    @ViewBuilder
    private var localPushSection: some View {
        if urlType.hasLocalPush {
            Section {
                Toggle(L10n.SettingsDetails.Notifications.LocalPush.title, isOn: $viewModel.localPush)

                Button(action: {
                    openURLInBrowser(
                        AppConstants.WebURLs.companionLocalPush,
                        nil
                    )
                }) {
                    Text(L10n.SettingsDetails.learnMore)
                }
            } footer: {
                Text(L10n.Settings.ConnectionSection.localPushDescription)
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var saveButton: some View {
        if viewModel.isChecking {
            ProgressView()
        } else {
            Button(L10n.saveLabel) {
                viewModel.save(onSuccess: onDismiss)
            }
            .tint(.haPrimary)
            .modify { view in
                if #available(iOS 26.0, *) {
                    view.buttonStyle(.glassProminent)
                } else {
                    view
                }
            }
        }
    }

    // MARK: - Location Permission Section

    @ViewBuilder
    private var locationPermissionSection: some View {
        if shouldShowLocationPermission {
            Section {
                Button(action: handleLocationPermission) {
                    Text(L10n.Settings.ConnectionSection.ssidPermissionAndAccuracyMessage)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    /// Determines if the security warning should be shown for non-HTTPS external URLs.
    ///
    /// The warning is displayed when:
    /// 1. The URL type is external (remote/internet connections)
    /// 2. The URL does not use HTTPS protocol
    ///
    /// This helps encourage users to use encrypted connections for remote access,
    /// protecting their credentials and data from potential interception.
    private var shouldShowSecurityWarning: Bool {
        guard urlType == .external else { return false }
        guard let url = URL(string: viewModel.url.trimmingCharacters(in: .whitespaces)) else { return false }
        return url.scheme?.lowercased() != "https"
    }

    /// Determines if the location permission prompt should be shown.
    ///
    /// The prompt is shown when location permissions are insufficient for SSID detection:
    /// - On iOS 14+: Requires both "Always Allow" authorization AND full accuracy
    /// - On iOS 13 and earlier: Only requires "Always Allow" authorization
    ///
    /// SSID information requires "Always Allow" because the app needs to detect
    /// network changes in the background. Full accuracy is needed on iOS 14+ to
    /// access detailed network information including SSID names.
    private var shouldShowLocationPermission: Bool {
        let manager = CLLocationManager()
        if #available(iOS 14.0, *) {
            return manager.authorizationStatus != .authorizedAlways ||
                manager.accuracyAuthorization != .fullAccuracy
        } else {
            return manager.authorizationStatus != .authorizedAlways
        }
    }

    /// Handles location permission requests based on current authorization state.
    ///
    /// - If permissions have never been requested (.notDetermined):
    ///   Requests "Always Allow" authorization from the system
    /// - If permissions were previously requested (any other state):
    ///   Opens Settings app to the location permissions page for manual adjustment
    ///
    /// This two-step approach is necessary because:
    /// 1. iOS only allows requesting permissions once programmatically
    /// 2. After the initial request, users must change permissions in Settings
    private func handleLocationPermission() {
        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        } else {
            UIApplication.shared.openSettings(destination: .location)
        }
    }
}

#if DEBUG
struct ConnectionURLView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConnectionURLView(
                    server: ServerFixture.standard,
                    urlType: .internal,
                    onDismiss: {}
                )
            }
            .previewDisplayName("Internal URL")

            NavigationView {
                ConnectionURLView(
                    server: ServerFixture.standard,
                    urlType: .external,
                    onDismiss: {}
                )
            }
            .previewDisplayName("External URL")
        }
    }
}
#endif
