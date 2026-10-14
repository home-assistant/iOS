import HAKit
import Shared
import SwiftUI

/// SwiftUI view for managing server connection settings
struct ConnectionSettingsView: View {
    @StateObject private var viewModel: ConnectionSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettingsPresenter) private var appSettingsPresenter
    @State private var shareWrapper: ShareWrapper?
    @State private var isDeleteConfirmationPresented = false
    @State private var deleteError: Error?
    @State private var showDeleteError = false
    @State private var showInternalURLSheet = false
    @State private var showExternalURLSheet = false
    @State private var showLocationPrivacySheet = false
    @State private var showSensorPrivacySheet = false
    @State private var nameBeingEdited: ServerDetailsRowView.EditOption?
    @State private var nameDraft = ""
    @State private var showHowItWorksSheet = false
    @Namespace private var urlTransitionNamespace

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
        .navigationTitle(L10n.Settings.ConnectionSection.serverDetailsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ServerDetailsRowView.EditOption.allCases, id: \.self) { option in
                        Button {
                            edit(option)
                        } label: {
                            Label(option.title, systemSymbol: option.symbol)
                        }
                    }
                } label: {
                    Image(systemSymbol: .pencil)
                }
                .tint(.haPrimary)
                .accessibilityLabel(L10n.editLabel)
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.canShareServer {
                    Button {
                        if let invitationURL = viewModel.invitationURL() {
                            shareWrapper = ShareWrapper(url: invitationURL)
                        }
                    } label: {
                        Image(systemSymbol: .squareAndArrowUp)
                    }
                    .tint(.haPrimary)
                }
            }
        }
        .shareSheet(item: $shareWrapper)
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
            .modify { view in
                if #available(iOS 18.0, *) {
                    view.navigationTransition(
                        .zoom(sourceID: ServerDetailsRowView.EditOption.internalURL, in: urlTransitionNamespace)
                    )
                } else {
                    view
                }
            }
        }
        .sheet(isPresented: $showHowItWorksSheet) {
            NavigationView {
                ConnectionURLsHowItWorksView(server: viewModel.server)
                    .navigationViewStyle(.stack)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            CloseButton {
                                showHowItWorksSheet = false
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
            .modify { view in
                if #available(iOS 18.0, *) {
                    view.navigationTransition(
                        .zoom(sourceID: ServerDetailsRowView.EditOption.externalURL, in: urlTransitionNamespace)
                    )
                } else {
                    view
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
            WebSocketStatusView(state: viewModel.websocketState)

            LocalPushStatusRow(
                title: L10n.SettingsDetails.Notifications.LocalPush.title,
                value: viewModel.localPushStatus,
                canRetry: viewModel.canRetryLocalPush,
                retryAction: viewModel.retryLocalPush
            )

            NavigationLink {
                WebhookDetailView(server: viewModel.server)
            } label: {
                Text(L10n.Settings.ConnectionSection.Webhook.title)
            }
        }
    }

    // MARK: - Details Section

    private var serverDetails: [ServerDetailsRowView.Detail] {
        [
            .init(
                option: .deviceName,
                value: viewModel.deviceName.isEmpty ? Current.device.deviceName() : viewModel.deviceName,
                isPlaceholder: viewModel.deviceName.isEmpty
            ),
            .init(
                option: .internalURL,
                value: viewModel.internalURL,
                isActive: viewModel.activeURLType == .internal && viewModel.internalURL != nil
            ),
            .init(
                option: .externalURL,
                value: viewModel.externalURL,
                isActive: (viewModel.activeURLType == .external || viewModel.activeURLType == .remoteUI)
                    && viewModel.externalURL != nil,
                symbol: viewModel.isUsingCloud ? .icloud : nil
            ),
        ]
    }

    private var detailsSection: some View {
        Section {
            ServerDetailsRowView(
                serverName: viewModel.serverName,
                userName: viewModel.loggedInUser,
                profilePicture: viewModel.profilePicture,
                details: serverDetails,
                isSyncing: viewModel.isSyncing,
                transitionNamespace: urlTransitionNamespace,
                onEdit: edit,
                onSync: viewModel.updateAppDatabase,
                onTroubleshoot: { showHowItWorksSheet = true },
                onOpen: viewModel.hasMultipleServers ? openServer : nil
            )
            .alert(
                nameBeingEdited?.title ?? "",
                isPresented: Binding(
                    get: { nameBeingEdited != nil },
                    set: { if !$0 { nameBeingEdited = nil } }
                ),
                presenting: nameBeingEdited
            ) { option in
                TextField(namePlaceholder(for: option), text: $nameDraft)
                Button(L10n.cancelLabel, role: .cancel) {}
                Button(L10n.saveLabel) {
                    let newName = nameDraft.isEmpty ? nil : nameDraft
                    switch option {
                    case .locationName:
                        viewModel.updateLocationName(newName)
                    case .deviceName:
                        viewModel.updateDeviceName(newName)
                    case .internalURL, .externalURL:
                        break
                    }
                }
            }
        } footer: {
            if !viewModel.version.isEmpty {
                Text(L10n.Settings.ConnectionSection.serverVersionFooter(viewModel.version))
            }
        }
    }

    private func edit(_ option: ServerDetailsRowView.EditOption) {
        switch option {
        case .locationName:
            nameDraft = viewModel.locationName
            nameBeingEdited = option
        case .deviceName:
            nameDraft = viewModel.deviceName
            nameBeingEdited = option
        case .internalURL:
            showInternalURLSheet = true
        case .externalURL:
            showExternalURLSheet = true
        }
    }

    private func namePlaceholder(for option: ServerDetailsRowView.EditOption) -> String {
        switch option {
        case .locationName:
            return viewModel.server.info.remoteName
        case .deviceName:
            return Current.device.deviceName()
        case .internalURL, .externalURL:
            return ""
        }
    }

    // MARK: - Client Certificate Section

    private var clientCertificateSection: some View {
        Section {
            NavigationLink {
                ClientCertificateView(viewModel: viewModel)
            } label: {
                NavigationRow(
                    title: L10n.Settings.ConnectionSection.ClientCertificate.header,
                    value: viewModel.clientCertificate?.displayName
                        ?? L10n.Settings.ConnectionSection.ClientCertificate.notConfigured,
                    valueColor: .secondary
                )
            }
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

    // MARK: - Open Server

    private func openServer() {
        viewModel.activateServer()
        dismissAppSettings()
    }

    private func dismissAppSettings() {
        appSettingsPresenter?.isSheetPresented = false
        appSettingsPresenter?.isPushPresented = false
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

extension ConnectionSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Settings.StatusSection.LocationNameRow.title),
            SettingsSearchEntry(L10n.SettingsDetails.General.DeviceName.title),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.InternalBaseUrl.title),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.ExternalBaseUrl.title),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.title),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.syncServer),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.ClientCertificate.header),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.LocationSendType.title),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.SensorSendType.title),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.Websocket.title),
            SettingsSearchEntry(L10n.SettingsDetails.Notifications.LocalPush.title),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.Webhook.title),
            SettingsSearchEntry(L10n.Settings.ConnectionSection.DeleteServer.title),
        ]
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

private struct LocalPushStatusRow: View {
    let title: String
    let value: String
    let canRetry: Bool
    let retryAction: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
            Button(action: retryAction) {
                Image(systemSymbol: .arrowClockwise)
            }
            .buttonStyle(.borderless)
            .disabled(!canRetry)
            .accessibilityLabel(L10n.SettingsDetails.Notifications.LocalPush.Retry.title)
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
