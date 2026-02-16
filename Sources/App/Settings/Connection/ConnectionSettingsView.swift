import HAKit
import Shared
import SwiftUI
import UniformTypeIdentifiers
import Version

/// SwiftUI view for managing server connection settings
struct ConnectionSettingsView: View {
    @StateObject private var viewModel: ConnectionSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showSecurityLevelPicker = false
    @State private var activityViewController: UIActivityViewController?
    @State private var isDeleteConfirmationPresented = false
    @State private var deleteError: Error?
    @State private var showDeleteError = false
    @State private var showInternalURLSheet = false
    @State private var showExternalURLSheet = false
    @State private var showLocationPrivacySheet = false
    @State private var showSensorPrivacySheet = false
    @State private var showCertificateImporter = false
    @State private var showCertificatePasswordPrompt = false
    @State private var certificatePassword = ""
    @State private var pendingCertificateURL: URL?
    @State private var showRemoveCertificateConfirmation = false

    let onDismiss: (() -> Void)?

    init(server: Server, onDismiss: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: ConnectionSettingsViewModel(server: server))
        self.onDismiss = onDismiss
    }

    var body: some View {
        List {
            detailsSection
            clientCertificateSection
            privacySection
            statusSection
            deleteSection
        }
        .navigationTitle(viewModel.serverName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.hasMultipleServers {
                    activateSection
                }
            }
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
                    .tint(.haPrimary)
                    .modify { view in
                        if #available(iOS 26.0, *), !Current.isCatalyst {
                            view.buttonStyle(.glassProminent)
                        } else {
                            view
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let activityVC = activityViewController {
                embed(activityVC)
            }
        }
        .sheet(isPresented: $showInternalURLSheet) {
            NavigationView {
                ConnectionURLView(
                    server: viewModel.server,
                    urlType: .internal
                )
                .navigationViewStyle(.stack)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton {
                            showInternalURLSheet = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showExternalURLSheet) {
            NavigationView {
                ConnectionURLView(
                    server: viewModel.server,
                    urlType: .external
                )
                .navigationViewStyle(.stack)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton {
                            showExternalURLSheet = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showLocationPrivacySheet) {
            NavigationView {
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
                .navigationViewStyle(.stack)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton {
                            showLocationPrivacySheet = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSensorPrivacySheet) {
            NavigationView {
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
                .navigationViewStyle(.stack)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton {
                            showSensorPrivacySheet = false
                        }
                    }
                }
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
        .fileImporter(
            isPresented: $showCertificateImporter,
            allowedContentTypes: [UTType(filenameExtension: "p12")!, UTType(filenameExtension: "pfx")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pendingCertificateURL = url
                    showCertificatePasswordPrompt = true
                }
            case .failure(let error):
                Current.Log.error("Failed to select certificate file: \(error)")
            }
        }
        .alert(L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.title, isPresented: $showCertificatePasswordPrompt) {
            SecureField(L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.placeholder, text: $certificatePassword)
            Button(L10n.cancelLabel, role: .cancel) {
                certificatePassword = ""
                pendingCertificateURL = nil
            }
            Button(L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.importButton) {
                if let url = pendingCertificateURL {
                    Task {
                        await viewModel.importCertificate(from: url, password: certificatePassword)
                        certificatePassword = ""
                        pendingCertificateURL = nil
                    }
                }
            }
        } message: {
            Text(L10n.Settings.ConnectionSection.ClientCertificate.PasswordPrompt.message)
        }
        .alert(
            L10n.Settings.ConnectionSection.ClientCertificate.ImportError.title,
            isPresented: Binding(
                get: { viewModel.certificateError != nil },
                set: { if !$0 { viewModel.certificateError = nil } }
            ),
            presenting: viewModel.certificateError
        ) { _ in
            Button(L10n.okLabel, role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .confirmationDialog(
            L10n.Settings.ConnectionSection.ClientCertificate.RemoveConfirmation.title,
            isPresented: $showRemoveCertificateConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Settings.ConnectionSection.ClientCertificate.RemoveConfirmation.remove, role: .destructive) {
                viewModel.removeCertificate()
            }
            Button(L10n.cancelLabel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.ConnectionSection.ClientCertificate.RemoveConfirmation.message)
        }
        .onDisappear {
            onDismiss?()
        }
        .alert(
            L10n.Settings.ConnectionSection.DeleteServer.title,
            isPresented: $showDeleteError,
            presenting: deleteError
        ) { _ in
            Button(L10n.okLabel, role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
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

            if #available(iOS 26.0, *) {
                NavigationLink {
                    ConnectionURLView(
                        server: viewModel.server,
                        urlType: .internal
                    )
                } label: {
                    NavigationRow(
                        title: L10n.Settings.ConnectionSection.InternalBaseUrl.title,
                        value: viewModel.internalURL
                    )
                }

                NavigationLink {
                    ConnectionURLView(
                        server: viewModel.server,
                        urlType: .external
                    )
                } label: {
                    NavigationRow(
                        title: L10n.Settings.ConnectionSection.ExternalBaseUrl.title,
                        value: viewModel.externalURL
                    )
                }
            } else {
                Button {
                    showInternalURLSheet = true
                } label: {
                    NavigationRow(
                        title: L10n.Settings.ConnectionSection.InternalBaseUrl.title,
                        value: viewModel.internalURL
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    showExternalURLSheet = true
                } label: {
                    NavigationRow(
                        title: L10n.Settings.ConnectionSection.ExternalBaseUrl.title,
                        value: viewModel.externalURL
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button {
                showSecurityLevelPicker = true
            } label: {
                NavigationRow(
                    title: L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.title,
                    value: viewModel.securityLevel.description
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.updateAppDatabase()
            } label: {
                Label(L10n.Settings.ConnectionSection.refreshServer, systemSymbol: .arrowClockwise)
            }
        }
    }

    // MARK: - Client Certificate Section

    private var clientCertificateSection: some View {
        Section {
            if let certificate = viewModel.clientCertificate {
                // Certificate is configured
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(certificate.displayName)
                            .font(.body)
                        if certificate.isExpired {
                            Text(L10n.Settings.ConnectionSection.ClientCertificate.expired)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if let expiresAt = certificate.expiresAt {
                            Text(L10n.Settings.ConnectionSection.ClientCertificate.expiresAt(expiresAt.formatted(date: .abbreviated, time: .omitted)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemSymbol: .checkmarkShield)
                        .foregroundColor(.green)
                }

                Button(role: .destructive) {
                    showRemoveCertificateConfirmation = true
                } label: {
                    Label(L10n.Settings.ConnectionSection.ClientCertificate.remove, systemSymbol: .trash)
                }
            } else {
                // No certificate configured
                Button {
                    showCertificateImporter = true
                } label: {
                    if viewModel.isImportingCertificate {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text(L10n.Settings.ConnectionSection.ClientCertificate.importing)
                        }
                    } else {
                        Label(L10n.Settings.ConnectionSection.ClientCertificate.import, systemSymbol: .plusCircle)
                    }
                }
                .disabled(viewModel.isImportingCertificate)
            }
        } header: {
            Text(L10n.Settings.ConnectionSection.ClientCertificate.header)
        } footer: {
            Text(L10n.Settings.ConnectionSection.ClientCertificate.footer)
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section(header: Text(L10n.SettingsDetails.Privacy.title)) {
            if #available(iOS 26.0, *) {
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
                    NavigationRow(
                        title: L10n.Settings.ConnectionSection.LocationSendType.title,
                        value: viewModel.locationPrivacy.localizedDescription,
                        valueColor: .secondary
                    )
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
                    NavigationRow(
                        title: L10n.Settings.ConnectionSection.SensorSendType.title,
                        value: viewModel.sensorPrivacy.localizedDescription,
                        valueColor: .secondary
                    )
                }
            } else {
                Button {
                    showLocationPrivacySheet = true
                } label: {
                    NavigationRow(
                        title: L10n.Settings.ConnectionSection.LocationSendType.title,
                        value: viewModel.locationPrivacy.localizedDescription,
                        valueColor: .secondary
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    showSensorPrivacySheet = true
                } label: {
                    NavigationRow(
                        title: L10n.Settings.ConnectionSection.SensorSendType.title,
                        value: viewModel.sensorPrivacy.localizedDescription,
                        valueColor: .secondary
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Activate Section

    private var activateSection: some View {
        Button {
            viewModel.activateServer()
        } label: {
            Text(L10n.Settings.ConnectionSection.activateServer)
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
                            deleteError = error
                            showDeleteError = true
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

private struct NavigationRow: View {
    let title: String
    let value: String
    let valueColor: Color

    init(title: String, value: String, valueColor: Color = .haPrimary) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .lineLimit(1)
        }
    }
}

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
            case .rejected:
                return L10n.Settings.ConnectionSection.Websocket.Status.Rejected.title
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
