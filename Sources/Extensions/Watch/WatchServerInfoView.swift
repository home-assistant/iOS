import SFSafeSymbols
import Shared
import SwiftUI

/// Read-only watch settings. Lists the servers synchronized from the iPhone and, for each, shows
/// the connection details we already display on iOS (including mTLS client-certificate status).
/// Nothing here can be edited — the watch can only read the synced configuration or ask the phone
/// to push a fresh copy.
struct WatchServerInfoView: View {
    @StateObject private var viewModel = WatchServerInfoViewModel()

    var body: some View {
        NavigationView {
            List {
                serversSection
            }
            .navigationTitle(Text(verbatim: L10n.Watch.Settings.title))
        }
    }

    @ViewBuilder
    private var serversSection: some View {
        Section {
            if viewModel.servers.isEmpty {
                Text(verbatim: L10n.Watch.Settings.noServers)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                    NavigationLink {
                        WatchServerDetailView(server: server)
                    } label: {
                        Label {
                            Text(verbatim: server.info.name)
                        } icon: {
                            Image(systemSymbol: .network)
                        }
                    }
                }
            }
        } header: {
            Text(verbatim: L10n.Watch.Settings.Servers.header)
        } footer: {
            // When the synchronized data is from — refreshed via the Home screen's reload button.
            if let lastUpdated = viewModel.lastUpdated {
                Text(verbatim: L10n.Watch.Settings.lastUpdated(
                    lastUpdated.formatted(date: .abbreviated, time: .shortened)
                ))
            }
        }
    }
}

/// Read-only detail of a single synchronized server.
struct WatchServerDetailView: View {
    let server: Server

    private var connection: ConnectionInfo { server.info.connection }

    var body: some View {
        List {
            connectionSection
            statusSection
            clientCertificateSection
        }
        .navigationTitle(Text(verbatim: server.info.name))
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
                infoRow(
                    L10n.Watch.Settings.ClientCertificate.availableOnWatch,
                    ClientCertificateManager.shared.hasIdentity(for: certificate) ? L10n.yesLabel : L10n.noLabel
                )
            } else {
                Text(verbatim: L10n.Watch.Settings.ClientCertificate.none)
                    .foregroundStyle(.secondary)
            }
        }
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

final class WatchServerInfoViewModel: ObservableObject {
    @Published private(set) var servers: [Server] = []
    @Published private(set) var lastUpdated: Date?

    init() {
        Current.servers.add(observer: self)
        reload()
    }

    private func reload() {
        let all = Current.servers.all
        let updatedAt = WatchUserDefaults.shared.date(for: .serversUpdatedAt)
        DispatchQueue.main.async { [weak self] in
            self?.servers = all
            self?.lastUpdated = updatedAt
        }
    }
}

extension WatchServerInfoViewModel: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        reload()
    }
}
