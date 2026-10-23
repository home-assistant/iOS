import CoreLocation
import Foundation
import PromiseKit
import Shared
import SwiftUI

// Migrated to SwiftUI using Copilot agent https://github.com/home-assistant/iOS/pull/3956
struct ConnectionURLView: View {
    @Environment(\.dismiss) private var dismiss
    let urlType: ConnectionInfo.URLType

    @StateObject private var viewModel: ConnectionURLViewModel
    @State private var showSecurityLevelPicker = false

    init(server: Server, urlType: ConnectionInfo.URLType) {
        self.urlType = urlType
        _viewModel = StateObject(wrappedValue: ConnectionURLViewModel(server: server, urlType: urlType))
    }

    var body: some View {
        Form {
            AppleLikeListTopRowHeader(
                image: urlType == .internal ? .wifiIcon : .earthIcon,
                title: urlType.description,
                subtitle: headerSubtitle
            )
            cloudToggleSection
            urlSection
            homeNetworkSection
            localPushSection
            Section {
                ConnectionURLsHowItWorksLink(server: viewModel.server)
            }
        }
        .navigationTitle(L10n.editLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                saveButton
            }
        }
        .alert(L10n.Settings.ConnectionSection.ValidateError.title, isPresented: $viewModel.showError) {
            if viewModel.canCommitAnyway {
                Button(L10n.Settings.ConnectionSection.ValidateError.useAnyway) {
                    viewModel.commitAnyway(onSuccess: {
                        dismiss()
                    })
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
                Toggle(AppConstants.homeAssistantLinkName, isOn: $viewModel.useCloud)
            }
        }
    }

    // MARK: - URL Section

    private var headerSubtitle: String? {
        switch urlType {
        case .internal:
            return L10n.Settings.ConnectionSection.InternalBaseUrl.headerSubtitle
        case .external:
            return L10n.Settings.ConnectionSection.ExternalBaseUrl.headerSubtitle
        case .remoteUI, .none:
            return nil
        }
    }

    private var urlSection: some View {
        Section {
            urlInputOrCloudMessage
            if viewModel.showsSecurityLevel {
                Button {
                    showSecurityLevelPicker = true
                } label: {
                    HStack {
                        Text(L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.title)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(viewModel.securityLevel.description)
                            .foregroundColor(.secondary)
                        Image(systemSymbol: .chevronRight)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .sheet(isPresented: $showSecurityLevelPicker) {
                    LocalAccessPermissionViewInNavigationView(
                        initialSelection: viewModel.securityLevel,
                        action: applySecurityLevel
                    )
                }
            }
        } header: {
            Text(L10n.Settings.ConnectionSection.UrlAddress.header)
        } footer: {
            if viewModel.showsSecurityLevel {
                Text(L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.footer)
            }
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
            Text(L10n.Settings.ConnectionSection.cloudLinkOverridesExternal(AppConstants.homeAssistantLinkName))
                .foregroundColor(.secondary)
                .font(.footnote)
        }
    }

    private var urlTextField: some View {
        TextField(viewModel.placeholder, text: $viewModel.url)
            .foregroundColor(.haPrimary)
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

    private func applySecurityLevel(_ level: ConnectionSecurityLevel) {
        viewModel.securityLevel = level
        showSecurityLevelPicker = false
    }

    // MARK: - Home Network Section

    @ViewBuilder
    private var homeNetworkSection: some View {
        if urlType.isAffectedBySSID {
            Section {
                if shouldShowLocationPermission {
                    HAAlertView(
                        title: L10n.Settings.ConnectionSection.NetworkDetectionPermission.title,
                        alertType: .warning,
                        narrow: true
                    ) {
                        Text(L10n.Settings.ConnectionSection.NetworkDetectionPermission.message)
                    } action: {
                        Button(
                            L10n.Settings.ConnectionSection.NetworkDetectionPermission.allow,
                            action: handleLocationPermission
                        )
                        .buttonStyle(.bordered)
                        .tint(.haWarning)
                    }
                }

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

                if urlType.isAffectedByHardwareAddress {
                    NavigationLink(destination: ConnectionHardwareAddressesView(viewModel: viewModel)) {
                        LabeledContent(
                            L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.title,
                            value: String(viewModel.hardwareAddresses.filter { !$0.isEmpty }.count)
                        )
                    }
                }
            } header: {
                Text(L10n.Settings.ConnectionSection.HomeNetwork.header)
            } footer: {
                Text(L10n.Settings.ConnectionSection.InternalUrlSsids.footer)
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
                viewModel.save(onSuccess: {
                    dismiss()
                })
            }
            .tint(.haPrimary)
            .disabled(!viewModel.hasChanges)
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
    /// - Requires both "Always Allow" authorization AND full accuracy
    ///
    /// Full accuracy is what makes the SSID readable at all — with approximate location iOS never
    /// hands the network name out, not even while the app is in the foreground. "Always Allow" is
    /// needed on top of that for the SSID to stay readable while the app is in the background,
    /// which is when sensor updates, notification actions and local push run.
    private var shouldShowLocationPermission: Bool {
        Current.locationManager.currentPermissionState != .authorizedAlways ||
            Current.locationManager.accuracyAuthorization != .fullAccuracy
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
        if Current.locationManager.currentPermissionState == .notDetermined {
            Current.locationManager.requestLocationPermission()
        } else {
            URLOpener.shared.openSettings(destination: .location, completionHandler: nil)
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
                    urlType: .internal
                )
            }
            .previewDisplayName("Internal URL")

            NavigationView {
                ConnectionURLView(
                    server: ServerFixture.standard,
                    urlType: .external
                )
            }
            .previewDisplayName("External URL")
        }
    }
}
#endif
