import Communicator
import SFSafeSymbols
import Shared
import SwiftUI

/// Read-only detail of a single synchronized server.
struct WatchServerDetailView: View {
    let server: Server

    private var connection: ConnectionInfo { server.info.connection }

    /// Bumped when client certificates are imported so the "Available on this Watch" row re-reads
    /// the Keychain while this screen is open (the import arrives asynchronously).
    @State private var certRefreshToken = UUID()
    @State private var showImportInstructions = false
    @State private var showRemoveFromWatchConfirmation = false
    /// `nil` = automatic; otherwise the URL the Watch is forced to use for this server.
    @State private var urlOverride: ConnectionInfo.URLType?

    init(server: Server) {
        self.server = server
        let raw = WatchUserDefaults.shared.urlOverrideRawValue(forServerId: server.identifier.rawValue)
        _urlOverride = State(initialValue: raw.flatMap(ConnectionInfo.URLType.init(rawValue:)))
    }

    var body: some View {
        List {
            urlOverrideSection
            connectionSection
            statusSection
            clientCertificateSection
        }
        .navigationTitle(Text(verbatim: server.info.name))
        .id(certRefreshToken)
        .onReceive(NotificationCenter.default.publisher(for: .clientCertificatesImported)) { _ in
            certRefreshToken = UUID()
        }
        .alert(
            Text(verbatim: L10n.Settings.ConnectionSection.ClientCertificate.import),
            isPresented: $showImportInstructions
        ) {
            Button(L10n.Watch.Settings.refresh) {
                WatchServerSync.request()
            }
        } message: {
            Text(verbatim: L10n.Watch.Settings.ClientCertificate.importInstructions)
        }
    }

    /// Number of distinct URLs configured for this server (internal / external / remote-UI).
    private var configuredURLCount: Int {
        [ConnectionInfo.URLType.internal, .external, .remoteUI]
            .compactMap { connection.address(for: $0) }
            .count
    }

    @ViewBuilder
    private var urlOverrideSection: some View {
        // Only meaningful when there's a choice of URLs to force.
        if configuredURLCount > 1 {
            Section {
                Picker(L10n.Watch.Settings.UrlOverride.title, selection: $urlOverride) {
                    Text(verbatim: L10n.Watch.Settings.auto)
                        .tag(ConnectionInfo.URLType?.none)
                    Text(verbatim: L10n.Settings.ConnectionSection.InternalBaseUrl.title)
                        .tag(ConnectionInfo.URLType?.some(.internal))
                    Text(verbatim: L10n.Settings.ConnectionSection.ExternalBaseUrl.title)
                        .tag(ConnectionInfo.URLType?.some(.external))
                }
                .onChange(of: urlOverride) { newValue in
                    WatchUserDefaults.shared.setURLOverrideRawValue(
                        newValue?.rawValue,
                        forServerId: server.identifier.rawValue
                    )
                    WatchServerSync.applyURLOverrides()
                }
            } footer: {
                Text(verbatim: L10n.Watch.Settings.UrlOverride.footer)
            }
        }
    }

    private var connectionSection: some View {
        Section(header: Text(verbatim: L10n.Settings.ConnectionSection.details)) {
            infoRow(L10n.Settings.ConnectionSection.InternalBaseUrl.title, connection.internalURL?.absoluteString)
            infoRow(
                L10n.Settings.ConnectionSection.ExternalBaseUrl.title,
                connection.address(for: .external)?.absoluteString
            )
            infoRow(
                L10n.Settings.ConnectionSection.RemoteUiUrl.title,
                connection.address(for: .remoteUI)?.absoluteString
            )
        }
    }

    private var statusSection: some View {
        Section(header: Text(verbatim: L10n.Settings.StatusSection.header)) {
            infoRow(L10n.Settings.StatusSection.VersionRow.title, server.info.version.description)
        }
    }

    @ViewBuilder
    private var clientCertificateSection: some View {
        Section(header: Text(verbatim: L10n.Settings.ConnectionSection.ClientCertificate.header)) {
            if let certificate = connection.clientCertificate {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(verbatim: certificate.displayName)
                    if certificate.isExpired {
                        Text(verbatim: L10n.Settings.ConnectionSection.ClientCertificate.expired)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if let expiresAt = certificate.expiresAt {
                        Text(verbatim: L10n.Settings.ConnectionSection.ClientCertificate.expiresAt(
                            expiresAt.formatted(date: .abbreviated, time: .omitted)
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                // Whether the identity actually made it into this Watch's Keychain — the key signal
                // for debugging mTLS sync, since the Watch's Keychain is separate from the iPhone's.
                availabilityRow(for: certificate)
            } else {
                Text(verbatim: L10n.Watch.Settings.ClientCertificate.none)
                    .foregroundStyle(.secondary)
            }

            importButton
        }
    }

    @ViewBuilder
    private func availabilityRow(for certificate: ClientCertificate) -> some View {
        if ClientCertificateManager.shared.hasIdentity(for: certificate) {
            // Tappable: offer to remove the identity from THIS Watch's Keychain (the iPhone keeps it).
            Button {
                showRemoveFromWatchConfirmation = true
            } label: {
                HStack {
                    infoRow(L10n.Watch.Settings.ClientCertificate.availableOnWatch, L10n.yesLabel)
                    Spacer()
                    Image(systemSymbol: .trash)
                        .foregroundStyle(.red)
                }
            }
            .buttonStyle(.plain)
            .alert(
                Text(verbatim: L10n.Watch.Settings.ClientCertificate.RemoveFromWatch.title),
                isPresented: $showRemoveFromWatchConfirmation
            ) {
                Button(L10n.Watch.Settings.ClientCertificate.RemoveFromWatch.remove, role: .destructive) {
                    removeCertificateFromWatch(certificate)
                }
                Button(L10n.cancelLabel, role: .cancel) {}
            } message: {
                Text(verbatim: L10n.Watch.Settings.ClientCertificate.RemoveFromWatch.message)
            }
        } else {
            infoRow(L10n.Watch.Settings.ClientCertificate.availableOnWatch, L10n.noLabel)
        }
    }

    /// Delete the certificate's identity from THIS Watch's Keychain only. The iPhone's copy and the
    /// server configuration are untouched, so a later refresh re-delivers and re-imports it.
    private func removeCertificateFromWatch(_ certificate: ClientCertificate) {
        do {
            try ClientCertificateManager.shared.delete(certificate: certificate)
            Current.Log.info("[mTLS] Removed client certificate from this Watch: \(certificate.displayName)")
        } catch {
            Current.Log.error("[mTLS] Failed to remove client certificate from Watch: \(error)")
        }
        Current.resetAPICache(for: [server.identifier])
        certRefreshToken = UUID()
    }

    private var importButton: some View {
        Button {
            requestCertificateImport()
        } label: {
            Label(L10n.Settings.ConnectionSection.ClientCertificate.import, systemSymbol: .squareAndArrowDown)
        }
    }

    /// Ask the iPhone to present its certificate import screen for this server. iOS can't foreground
    /// the phone app from here, so the screen appears the next time the user opens Home Assistant on
    /// the phone; once imported, the next watch refresh delivers it inline.
    private func requestCertificateImport() {
        if Communicator.shared.currentReachability == .immediatelyReachable {
            Communicator.shared.send(.init(
                identifier: InteractiveImmediateMessages.clientCertImportRequest.rawValue,
                content: ["serverId": server.identifier.rawValue],
                reply: { _ in }
            ), errorHandler: { error in
                Current.Log.error("[mTLS] Failed to request certificate import: \(error)")
            })
        }
        showImportInstructions = true
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(verbatim: title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: value)
                    .font(.footnote)
            }
        }
    }
}
