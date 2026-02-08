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
        requirements = []

        // Check if home network is defined
        if server.info.connection.internalSSIDs?.isEmpty ?? true,
           server.info.connection.internalHardwareAddresses?.isEmpty ?? true {
            requirements.append(.homeNetworkMissing)
        } else {
            // Check if user is on home network
            if !server.info.connection.isOnInternalNetwork {
                requirements.append(.notOnHomeNetwork)
            }
        }

        // Check location permission
        let currentPermission = Current.locationManager.currentPermissionState
        if currentPermission != .authorizedAlways, currentPermission != .authorizedWhenInUse {
            requirements.append(.locationPermission)
        }
    }
}
