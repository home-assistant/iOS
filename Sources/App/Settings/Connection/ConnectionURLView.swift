import CoreLocation
import Foundation
import PromiseKit
import Shared
import SwiftUI

struct ConnectionURLView: View {
    let server: Server
    let urlType: ConnectionInfo.URLType
    let onDismiss: () -> Void

    @State private var url: String
    @State private var useCloud: Bool
    @State private var localPush: Bool
    @State private var ssids: [String]
    @State private var hardwareAddresses: [String]
    @State private var isChecking = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var canCommitAnyway = false

    init(server: Server, urlType: ConnectionInfo.URLType, onDismiss: @escaping () -> Void) {
        self.server = server
        self.urlType = urlType
        self.onDismiss = onDismiss

        // Initialize state
        _url = State(initialValue: server.info.connection.address(for: urlType)?.absoluteString ?? "")
        _useCloud = State(initialValue: server.info.connection.useCloud)
        _localPush = State(initialValue: server.info.connection.isLocalPushEnabled)
        _ssids = State(initialValue: server.info.connection.internalSSIDs ?? [])
        _hardwareAddresses = State(initialValue: server.info.connection.internalHardwareAddresses ?? [])
    }

    var body: some View {
        Form {
            if urlType.isAffectedByCloud, server.info.connection.canUseCloud {
                Section {
                    Toggle(L10n.Settings.ConnectionSection.HomeAssistantCloud.title, isOn: $useCloud)
                }
            }

            Section {
                if !useCloud || !urlType.isAffectedByCloud || !server.info.connection.canUseCloud {
                    TextField(placeholder, text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    Text(L10n.Settings.ConnectionSection.cloudOverridesExternal)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }

                if urlType == .internal {
                    Text(L10n.Settings.ConnectionSection.InternalBaseUrl.SsidRequired.title)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }

            if urlType.isAffectedBySSID {
                locationPermissionSection

                Section {
                    ForEach(ssids.indices, id: \.self) { index in
                        HStack {
                            TextField(L10n.Settings.ConnectionSection.InternalUrlSsids.placeholder, text: $ssids[index])
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                            Button(action: { ssids.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        ssids.remove(atOffsets: indexSet)
                    }

                    Button(action: addSSID) {
                        Text(L10n.Settings.ConnectionSection.InternalUrlSsids.addNewSsid)
                    }
                } header: {
                    Text(L10n.Settings.ConnectionSection.InternalUrlSsids.header)
                } footer: {
                    Text(L10n.Settings.ConnectionSection.InternalUrlSsids.footer)
                }
            }

            if urlType.isAffectedByHardwareAddress {
                Section {
                    ForEach(hardwareAddresses.indices, id: \.self) { index in
                        HStack {
                            TextField("aa:bb:cc:dd:ee:ff", text: $hardwareAddresses[index])
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                            Button(action: { hardwareAddresses.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        hardwareAddresses.remove(atOffsets: indexSet)
                    }

                    Button(action: addHardwareAddress) {
                        Text(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.addNewSsid)
                    }
                } header: {
                    Text(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.header)
                } footer: {
                    Text(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.footer)
                }
            }

            if urlType.hasLocalPush {
                Section {
                    Toggle(L10n.SettingsDetails.Notifications.LocalPush.title, isOn: $localPush)

                    Button(action: {
                        openURLInBrowser(
                            URL(string: "https://companion.home-assistant.io/app/ios/local-push")!,
                            nil
                        )
                    }) {
                        Text(L10n.Assist.LearnMore.title)
                    }
                } footer: {
                    Text(L10n.Settings.ConnectionSection.localPushDescription)
                }
            }
        }
        .navigationTitle(urlType.description)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancelLabel) {
                    onDismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if isChecking {
                    ProgressView()
                } else {
                    Button(L10n.saveLabel) {
                        save()
                    }
                }
            }
        }
        .alert(L10n.Settings.ConnectionSection.ValidateError.title, isPresented: $showError) {
            if canCommitAnyway {
                Button(L10n.Settings.ConnectionSection.ValidateError.useAnyway) {
                    commit()
                }
            }
            Button(L10n.Settings.ConnectionSection.ValidateError.editUrl, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

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

    private var shouldShowLocationPermission: Bool {
        let manager = CLLocationManager()
        if #available(iOS 14.0, *) {
            return manager.authorizationStatus != .authorizedAlways ||
                manager.accuracyAuthorization != .fullAccuracy
        } else {
            return manager.authorizationStatus != .authorizedAlways
        }
    }

    private var placeholder: String {
        switch urlType {
        case .internal:
            return L10n.Settings.ConnectionSection.InternalBaseUrl.placeholder
        case .external:
            return L10n.Settings.ConnectionSection.ExternalBaseUrl.placeholder
        case .remoteUI, .none:
            return ""
        }
    }

    private func addSSID() {
        let currentSSID = Current.connectivity.currentWiFiSSID()
        if let currentSSID, !ssids.contains(currentSSID) {
            ssids.append(currentSSID)
        } else {
            ssids.append("")
        }
    }

    private func addHardwareAddress() {
        let currentAddress = Current.connectivity.currentNetworkHardwareAddress()
        if let currentAddress, !hardwareAddresses.contains(currentAddress) {
            hardwareAddresses.append(currentAddress)
        } else {
            hardwareAddresses.append("")
        }
    }

    private func handleLocationPermission() {
        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        } else {
            UIApplication.shared.openSettings(destination: .location)
        }
    }

    private func save() {
        let givenURL = url.isEmpty ? nil : URL(string: url)

        isChecking = true

        firstly { () -> Promise<Void> in
            try check(url: givenURL, useCloud: useCloud)

            if useCloud, let remoteURL = server.info.connection.address(for: .remoteUI) {
                return Current.webhooks.sendTest(server: server, baseURL: remoteURL)
            }

            if let givenURL, !useCloud {
                return Current.webhooks.sendTest(server: server, baseURL: givenURL)
            }

            return .value(())
        }.ensure {
            isChecking = false
        }.done {
            commit()
        }.catch { error in
            handleError(error)
        }
    }

    private func check(url: URL?, useCloud: Bool) throws {
        // Validate hardware addresses
        if urlType.isAffectedByHardwareAddress {
            let pattern = "^[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}$"
            let regex = try? NSRegularExpression(pattern: pattern)

            for address in hardwareAddresses where !address.isEmpty {
                let range = NSRange(location: 0, length: address.utf16.count)
                if regex?.firstMatch(in: address, range: range) == nil {
                    throw SaveError.validation(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.invalid)
                }
            }
        }

        // Check if removing last URL
        if url == nil {
            let existingInfo = server.info.connection
            let other: ConnectionInfo.URLType = urlType == .internal ? .external : .internal
            if existingInfo.address(for: other) == nil,
               !useCloud || !existingInfo.useCloud {
                throw SaveError.lastURL
            }
        }
    }

    private func commit() {
        let givenURL = url.isEmpty ? nil : URL(string: url)

        server.update { info in
            info.connection.set(address: givenURL, for: urlType)
            info.connection.useCloud = useCloud
            info.connection.isLocalPushEnabled = localPush
            info.connection.internalSSIDs = ssids.filter { !$0.isEmpty }
            info.connection.internalHardwareAddresses = hardwareAddresses
                .map { $0.lowercased() }
                .filter { !$0.isEmpty }
        }

        onDismiss()
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription

        if let saveError = error as? SaveError {
            canCommitAnyway = !saveError.isFinal
        } else {
            canCommitAnyway = true
        }

        showError = true
    }

    enum SaveError: LocalizedError {
        case lastURL
        case validation(String)

        var errorDescription: String? {
            switch self {
            case .lastURL:
                return L10n.Settings.ConnectionSection.Errors.cannotRemoveLastUrl
            case let .validation(message):
                return message
            }
        }

        var isFinal: Bool {
            switch self {
            case .lastURL, .validation:
                return true
            }
        }
    }
}

#if DEBUG
struct ConnectionURLView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConnectionURLView(
                    server: ServerManager.shared.server,
                    urlType: .internal,
                    onDismiss: {}
                )
            }
            .previewDisplayName("Internal URL")

            NavigationView {
                ConnectionURLView(
                    server: ServerManager.shared.server,
                    urlType: .external,
                    onDismiss: {}
                )
            }
            .previewDisplayName("External URL")
        }
    }
}
#endif
