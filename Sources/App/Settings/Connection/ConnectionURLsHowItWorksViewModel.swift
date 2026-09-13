import CoreLocation
import Foundation
import Shared

/// Backs `ConnectionURLsHowItWorksView`: works out which of the requirements for reaching this server
/// on its internal URL the device already meets, and which URL a request would use right now.
@MainActor
final class ConnectionURLsHowItWorksViewModel: ObservableObject {
    struct Requirement: Identifiable, Equatable {
        enum Kind: String {
            case internalURL
            case listedNetworks
            case preciseLocation
            case alwaysLocation
            case onListedNetwork
        }

        let kind: Kind
        let title: String
        let isMet: Bool

        var id: String { kind.rawValue }
    }

    @Published private(set) var requirements: [Requirement] = []
    @Published private(set) var activeURLType: ConnectionInfo.URLType = .none
    @Published private(set) var activeURL: URL?
    @Published private(set) var securityLevel: ConnectionSecurityLevel = .undefined

    private let server: Server

    init(server: Server) {
        self.server = server
        evaluate(
            connection: server.info.connection,
            networkState: Current.connectivity.lastKnownNetworkState()
        )
    }

    /// Re-evaluates against fresh network information, so what the screen shows matches what a real
    /// request would do right now rather than the last Wi-Fi name the app happened to read.
    func refresh() async {
        await Current.connectivity.refreshNetworkInformation()
        evaluate(
            connection: server.info.connection,
            networkState: Current.connectivity.lastKnownNetworkState()
        )
    }

    /// `connectionInfo` is a copy of the server's connection info, so evaluating URLs on it here has
    /// no effect on the connection the rest of the app uses.
    private func evaluate(connection connectionInfo: ConnectionInfo, networkState: NetworkState) {
        var connection = connectionInfo
        let resolvedURL = connection.evaluateActiveURL()
        activeURL = resolvedURL
        activeURLType = resolvedURL == nil ? ConnectionInfo.URLType.none : connection.activeURLType

        securityLevel = connectionInfo.connectionAccessSecurityLevel

        let ssids = connectionInfo.internalSSIDs ?? []
        let hardwareAddresses = connectionInfo.internalHardwareAddresses ?? []

        var resolved: [Requirement] = [
            Requirement(
                kind: .internalURL,
                title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Criteria.internalUrl,
                isMet: connectionInfo.hasInternalURLSet
            ),
        ]

        if Current.isCatalyst {
            // A Mac matches its home network by the hardware address of the active interface, so
            // none of the location requirements apply there.
            resolved.append(Requirement(
                kind: .listedNetworks,
                title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Criteria.hardwareAddresses,
                isMet: !hardwareAddresses.isEmpty
            ))
        } else {
            resolved.append(Requirement(
                kind: .listedNetworks,
                title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Criteria.ssids,
                isMet: !ssids.isEmpty
            ))
            resolved.append(Requirement(
                kind: .preciseLocation,
                title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Criteria.preciseLocation,
                isMet: Current.locationManager.accuracyAuthorization == .fullAccuracy
            ))
            resolved.append(Requirement(
                kind: .alwaysLocation,
                title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Criteria.alwaysLocation,
                isMet: Current.locationManager.currentPermissionState == .authorizedAlways
            ))
        }

        resolved.append(Requirement(
            kind: .onListedNetwork,
            title: L10n.Settings.ConnectionSection.UrlsHowItWorks.Criteria.listedNetwork,
            isMet: isOnListedNetwork(networkState: networkState, ssids: ssids, hardwareAddresses: hardwareAddresses)
        ))

        requirements = resolved
    }

    private func isOnListedNetwork(
        networkState: NetworkState,
        ssids: [String],
        hardwareAddresses: [String]
    ) -> Bool {
        if let ssid = networkState.ssid, ssids.contains(ssid) {
            return true
        }

        if let hardwareAddress = networkState.hardwareAddress, hardwareAddresses.contains(hardwareAddress) {
            return true
        }

        return false
    }
}
