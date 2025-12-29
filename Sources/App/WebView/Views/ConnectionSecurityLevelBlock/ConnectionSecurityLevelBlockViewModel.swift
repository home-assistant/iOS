import Foundation
import SFSafeSymbols
import Shared

final class ConnectionSecurityLevelBlockViewModel: ObservableObject {
    enum Requirement {
        case homeNetworkMissing
        case notOnHomeNetwork
        case locationPermission

        var title: String {
            switch self {
            case .homeNetworkMissing:
                return L10n.ConnectionSecurityLevelBlock.Requirement.HomeNetworkMissing.title
            case .notOnHomeNetwork:
                return L10n.ConnectionSecurityLevelBlock.Requirement.NotOnHomeNetwork.title
            case .locationPermission:
                return L10n.ConnectionSecurityLevelBlock.Requirement.LocationPermissionMissing.title
            }
        }

        var systemSymbol: SFSymbol {
            switch self {
            case .homeNetworkMissing:
                return .wifi
            case .notOnHomeNetwork:
                return .wifiSlash
            case .locationPermission:
                return .location
            }
        }
    }

    @Published var requirements: [Requirement] = []

    private let server: Server

    init(server: Server) {
        self.server = server
    }

    func loadRequirements() {
        Task { @MainActor in
            var newRequirements: [Requirement] = []

            // Check if home network is defined
            if server.info.connection.internalSSIDs?.isEmpty ?? true,
               server.info.connection.internalHardwareAddresses?.isEmpty ?? true {
                newRequirements.append(.homeNetworkMissing)
            } else {
                // Check if user is on home network (fetch real-time network info)
                let isOnInternal = await server.info.connection.isOnInternalNetwork()
                if !isOnInternal {
                    newRequirements.append(.notOnHomeNetwork)
                }
            }

            // Check location permission
            let currentPermission = Current.locationManager.currentPermissionState
            if currentPermission != .authorizedAlways, currentPermission != .authorizedWhenInUse {
                newRequirements.append(.locationPermission)
            }

            requirements = newRequirements
        }
    }
}
