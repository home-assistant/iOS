import Foundation
#if os(iOS)
import CoreTelephony
import Reachability
#endif

/// Wrapper around CoreTelephony, Reachability
public class ConnectivityWrapper {
    public var connectivityDidChangeNotification: () -> Notification.Name
    public var hasWiFi: () -> Bool
    public var currentWiFiSSID: () -> String?
    public var currentWiFiBSSID: () -> String?
    public var simpleNetworkType: () -> NetworkType
    public var cellularNetworkType: () -> NetworkType
    public var networkAttributes: () -> [String: Any]

    init() {
        hasWiFi = { ConnectionInfo.hasWiFi }
        currentWiFiSSID = { ConnectionInfo.CurrentWiFiSSID }
        currentWiFiBSSID = { ConnectionInfo.CurrentWiFiBSSID }

        #if targetEnvironment(macCatalyst)
        connectivityDidChangeNotification = { Current.macBridge.networkConnectivityDidChangeNotification }
        simpleNetworkType = {
            switch Current.macBridge.networkConnectivity.networkType {
            case .ethernet: return .ethernet
            case .wifi: return .wifi
            case .unknown: return .unknown
            case .noNetwork: return .noConnection
            }
        }
        cellularNetworkType = { .unknown }
        networkAttributes = {
            if let interface = Current.macBridge.networkConnectivity.interface {
                return [
                    "Name": interface.name,
                    "Hardware Address": interface.hardwareAddress
                ]
            } else {
                return [:]
            }
        }
        #elseif os(iOS)
        let reachability = try? Reachability()

        do {
            try reachability?.startNotifier()
        } catch {
            Current.Log.error("failed to start reachability notifier: \(error)")
        }
        connectivityDidChangeNotification = { .reachabilityChanged }
        simpleNetworkType = { reachability?.getSimpleNetworkType() ?? .unknown }
        cellularNetworkType = { reachability?.getNetworkType() ?? .unknown }
        networkAttributes = { [:] }
        #else
        connectivityDidChangeNotification = { .init(rawValue: "_noop_") }
        simpleNetworkType = { .unknown }
        cellularNetworkType = { .unknown }
        networkAttributes = { [:] }
        #endif
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    public var telephonyCarriers: () -> [String: CTCarrier]? = {
        CTTelephonyNetworkInfo().serviceSubscriberCellularProviders
    }
    public var telephonyRadioAccessTechnology: () -> [String: String]? = {
        CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology
    }
    #endif
}
