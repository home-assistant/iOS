import Foundation
#if os(iOS)
import CoreTelephony
import Reachability
#endif

public enum NetworkType: Int, CaseIterable {
    case unknown
    case noConnection
    case wifi
    case cellular
    case ethernet
    case wwan2g
    case wwan3g
    case wwan4g
    case wwan5g
    case unknownTechnology

    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .noConnection:
            return "No Connection"
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .wwan2g:
            return "2G"
        case .wwan3g:
            return "3G"
        case .wwan4g:
            return "4G"
        case .wwan5g:
            return "5G"
        case .unknownTechnology:
            return "Unknown Technology"
        }
    }

    var icon: String {
        switch self {
        case .unknown, .unknownTechnology:
            return "mdi:help-circle"
        case .noConnection:
            return "mdi:sim-off"
        case .wifi:
            return "mdi:wifi"
        case .cellular:
            return "mdi:signal"
        case .ethernet:
            return "mdi:ethernet"
        case .wwan2g:
            return "mdi:signal-2g"
        case .wwan3g:
            return "mdi:signal-3g"
        case .wwan4g:
            return "mdi:signal-4g"
        case .wwan5g:
            return "mdi:signal-5g"
        }
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    init(_ radioTech: String) {
        if #available(iOS 14.1, *), [CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA].contains(radioTech) {
            // although these are declared available in 14.0, they will crash on use before 14.1
            self = .wwan5g
            return
        }

        switch radioTech {
        case CTRadioAccessTechnologyGPRS,
             CTRadioAccessTechnologyEdge,
             CTRadioAccessTechnologyCDMA1x:
            self = .wwan2g
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            self = .wwan3g
        case CTRadioAccessTechnologyLTE:
            self = .wwan4g
        default:
            Current.Log.warning("Unknown connection technology: \(radioTech)")
            self = .unknownTechnology
        }
    }
    #endif
}

#if os(iOS)
public extension Reachability {
    func getSimpleNetworkType() -> NetworkType {
        try? startNotifier()

        switch connection {
        case .none:
            return .noConnection
        case .wifi:
            return .wifi
        case .cellular:
            return .cellular
        case .unavailable:
            return .noConnection
        }
    }

    func getNetworkType() -> NetworkType {
        try? startNotifier()

        switch connection {
        case .none:
            return .noConnection
        case .wifi:
            return .wifi
        case .cellular:
            #if !targetEnvironment(macCatalyst)
            return Reachability.getWWANNetworkType()
            #else
            return .cellular
            #endif
        case .unavailable:
            return .noConnection
        }
    }

    #if !targetEnvironment(macCatalyst)
    static func getWWANNetworkType() -> NetworkType {
        let networkTypes = (CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology ?? [:])
            .sorted(by: { $0.key < $1.key })
            .map(\.value)
            .map(NetworkType.init(_:))

        return networkTypes.first(where: { $0 != .unknownTechnology }) ?? .unknown
    }
    #endif
}
#endif
