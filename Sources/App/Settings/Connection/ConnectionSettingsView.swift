import HAKit
import Shared
import SwiftUI
import Version

/// SwiftUI view for managing server connection settings
struct ConnectionSettingsView: View {
    @StateObject private var viewModel: ConnectionSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showSecurityLevelPicker = false
    @State private var activityViewController: UIActivityViewController?
    @State private var isDeleteConfirmationPresented = false
    
    let onDismiss: (() -> Void)?
    
    init(server: Server, onDismiss: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: ConnectionSettingsViewModel(server: server))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        List {
            statusSection
            detailsSection
            privacySection
            if viewModel.hasMultipleServers {
                activateSection
            }
            deleteSection
        }
        .navigationTitle(viewModel.serverName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.canShareServer {
                    Button {
                        if let activityVC = viewModel.shareServer() {
                            activityViewController = activityVC
                            showShareSheet = true
                        }
                    } label: {
                        Image(systemSymbol: .squareAndArrowUp)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let activityVC = activityViewController {
                ActivityViewController(activityViewController: activityVC)
            }
        }
        .sheet(isPresented: $showSecurityLevelPicker) {
            LocalAccessPermissionViewInNavigationView(
                initialSelection: viewModel.securityLevel,
                action: { level in
                    viewModel.updateSecurityLevel(level)
                    showSecurityLevelPicker = false
                }
            )
        }
        .onDisappear {
            onDismiss?()
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section(header: Text(L10n.Settings.StatusSection.header)) {
            LabelRow(
                title: L10n.Settings.ConnectionSection.connectingVia,
                value: viewModel.connectionPath
            )
            
            LabelRow(
                title: L10n.Settings.StatusSection.VersionRow.title,
                value: viewModel.version
            )
            
            WebSocketStatusView(state: viewModel.websocketState)
            
            LabelRow(
                title: L10n.SettingsDetails.Notifications.LocalPush.title,
                value: viewModel.localPushStatus
            )
            
            LabelRow(
                title: L10n.Settings.ConnectionSection.loggedInAs,
                value: viewModel.loggedInUser
            )
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        Section(header: Text(L10n.Settings.ConnectionSection.details)) {
            TextFieldRow(
                title: L10n.Settings.StatusSection.LocationNameRow.title,
                placeholder: viewModel.server.info.remoteName,
                text: Binding(
                    get: { viewModel.locationName },
                    set: { viewModel.updateLocationName($0.isEmpty ? nil : $0) }
                )
            )
            
            TextFieldRow(
                title: L10n.SettingsDetails.General.DeviceName.title,
                placeholder: Current.device.deviceName(),
                text: Binding(
                    get: { viewModel.deviceName },
                    set: { viewModel.updateDeviceName($0.isEmpty ? nil : $0) }
                )
            )
            
            NavigationLink {
                ViewControllerWrapper(
                    ConnectionURLViewController(
                        server: viewModel.server,
                        urlType: .internal
                    )
                )
            } label: {
                HStack {
                    Text(L10n.Settings.ConnectionSection.InternalBaseUrl.title)
                    Spacer()
                    Text(viewModel.internalURL)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            NavigationLink {
                ViewControllerWrapper(
                    ConnectionURLViewController(
                        server: viewModel.server,
                        urlType: .external
                    )
                )
            } label: {
                HStack {
                    Text(L10n.Settings.ConnectionSection.ExternalBaseUrl.title)
                    Spacer()
                    Text(viewModel.externalURL)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Button {
                showSecurityLevelPicker = true
            } label: {
                HStack {
                    Text(L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.title)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.securityLevel.description)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        Section(header: Text(L10n.SettingsDetails.Privacy.title)) {
            NavigationLink {
                PrivacyPickerView(
                    title: L10n.Settings.ConnectionSection.LocationSendType.title,
                    options: ServerLocationPrivacy.allCases,
                    selection: Binding(
                        get: { viewModel.locationPrivacy },
                        set: { viewModel.updateLocationPrivacy($0) }
                    ),
                    isDisabled: viewModel.versionRequiresLocationGPSOptional,
                    footerMessage: viewModel.versionRequiresLocationGPSOptional
                        ? Version.updateLocationGPSOptional.coreRequiredString
                        : nil
                )
            } label: {
                HStack {
                    Text(L10n.Settings.ConnectionSection.LocationSendType.title)
                    Spacer()
                    Text(viewModel.locationPrivacy.localizedDescription)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            NavigationLink {
                PrivacyPickerView(
                    title: L10n.Settings.ConnectionSection.SensorSendType.title,
                    options: ServerSensorPrivacy.allCases,
                    selection: Binding(
                        get: { viewModel.sensorPrivacy },
                        set: { viewModel.updateSensorPrivacy($0) }
                    ),
                    isDisabled: false,
                    footerMessage: nil
                )
            } label: {
                HStack {
                    Text(L10n.Settings.ConnectionSection.SensorSendType.title)
                    Spacer()
                    Text(viewModel.sensorPrivacy.localizedDescription)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    // MARK: - Activate Section
    
    private var activateSection: some View {
        Section {
            Button {
                viewModel.activateServer()
            } label: {
                Text(L10n.Settings.ConnectionSection.activateServer)
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Delete Section
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                isDeleteConfirmationPresented = true
            } label: {
                if viewModel.isDeleting {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text(L10n.Settings.ConnectionSection.DeleteServer.progress)
                    }
                } else {
                    Text(L10n.Settings.ConnectionSection.DeleteServer.title)
                }
            }
            .disabled(viewModel.isDeleting)
            .confirmationDialog(
                L10n.Settings.ConnectionSection.DeleteServer.title,
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(L10n.Settings.ConnectionSection.DeleteServer.title, role: .destructive) {
                    Task {
                        do {
                            try await viewModel.deleteServer()
                            dismiss()
                        } catch {
                            Current.Log.error("Failed to delete server: \(error)")
                        }
                    }
                }
                Button(L10n.cancelLabel, role: .cancel) {}
            } message: {
                Text(L10n.Settings.ConnectionSection.DeleteServer.message)
            }
        }
    }
}

// MARK: - Supporting Views

private struct LabelRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

private struct TextFieldRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
        }
    }
}

private struct WebSocketStatusView: View {
    let state: HAConnectionState?
    @State private var showAlert = false
    
    var body: some View {
        Button {
            showAlert = true
        } label: {
            HStack {
                Text(L10n.Settings.ConnectionSection.Websocket.title)
                    .foregroundColor(.primary)
                Spacer()
                Text(statusMessage)
                    .foregroundColor(.secondary)
                if case .disconnected = state {
                    Image(systemSymbol: .infoCircle)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .alert(L10n.Settings.ConnectionSection.Websocket.title, isPresented: $showAlert) {
            Button(L10n.copyLabel) {
                UIPasteboard.general.string = detailedMessage
            }
            Button(L10n.cancelLabel, role: .cancel) {}
        } message: {
            Text(detailedMessage)
        }
    }
    
    private var statusMessage: String {
        guard let state else { return "" }
        switch state {
        case .connecting:
            return L10n.Settings.ConnectionSection.Websocket.Status.connecting
        case .authenticating:
            return L10n.Settings.ConnectionSection.Websocket.Status.authenticating
        case .disconnected:
            return L10n.Settings.ConnectionSection.Websocket.Status.Disconnected.title
        case .ready:
            return L10n.Settings.ConnectionSection.Websocket.Status.connected
        }
    }
    
    private var detailedMessage: String {
        guard let state else { return "" }
        switch state {
        case let .disconnected(reason):
            switch reason {
            case let .waitingToReconnect(lastError: error, atLatest: atLatest, retryCount: count):
                var components = [String]()
                
                if let error {
                    components.append(L10n.Settings.ConnectionSection.Websocket.Status.Disconnected.error(
                        error.localizedDescription
                    ))
                }
                
                components.append(L10n.Settings.ConnectionSection.Websocket.Status.Disconnected.retryCount(count))
                components.append(L10n.Settings.ConnectionSection.Websocket.Status.Disconnected.nextRetry(
                    DateFormatter.localizedString(from: atLatest, dateStyle: .none, timeStyle: .medium)
                ))
                
                return components.joined(separator: "\n\n")
            case .disconnected:
                return L10n.Settings.ConnectionSection.Websocket.Status.Disconnected.title
            }
        default:
            return statusMessage
        }
    }
}

private struct PrivacyPickerView<T: CaseIterable & Hashable>: View where T: RawRepresentable, T.RawValue == String {
    let title: String
    let options: [T]
    @Binding var selection: T
    let isDisabled: Bool
    let footerMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                ForEach(options, id: \.self) { option in
                    Button {
                        if !isDisabled {
                            selection = option
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(localizedDescription(for: option))
                                .foregroundColor(isDisabled ? .secondary : .primary)
                            Spacer()
                            if selection == option {
                                Image(systemSymbol: .checkmark)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .disabled(isDisabled)
                }
            } footer: {
                if let footerMessage {
                    Text(footerMessage)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func localizedDescription(for option: T) -> String {
        if let locationPrivacy = option as? ServerLocationPrivacy {
            return locationPrivacy.localizedDescription
        } else if let sensorPrivacy = option as? ServerSensorPrivacy {
            return sensorPrivacy.localizedDescription
        }
        return String(describing: option)
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityViewController: UIActivityViewController
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}



#Preview {
    NavigationView {
        ConnectionSettingsView(server: Current.servers.all.first!)
    }
}
