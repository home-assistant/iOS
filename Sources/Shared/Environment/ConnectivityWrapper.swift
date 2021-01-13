import Foundation
#if os(iOS)
import CoreTelephony
import Reachability
import SystemConfiguration.CaptiveNetwork
#endif

/// Wrapper around CoreTelephony, Reachability
public class ConnectivityWrapper {
    public var connectivityDidChangeNotification: () -> Notification.Name
    public var hasWiFi: () -> Bool
    public var currentWiFiSSID: () -> String?
    public var currentWiFiBSSID: () -> String?
    public var currentNetworkHardwareAddress: () -> String?
    public var simpleNetworkType: () -> NetworkType
    public var cellularNetworkType: () -> NetworkType
    public var networkAttributes: () -> [String: Any]

    #if targetEnvironment(macCatalyst)
    init() {
        hasWiFi = { Current.macBridge.networkConnectivity.hasWiFi }
        currentWiFiSSID = { Current.macBridge.networkConnectivity.wifi?.ssid }
        currentWiFiBSSID = { Current.macBridge.networkConnectivity.wifi?.bssid }
        connectivityDidChangeNotification = { Current.macBridge.networkConnectivityDidChangeNotification }
        simpleNetworkType = {
            switch Current.macBridge.networkConnectivity.networkType {
            case .ethernet: return .ethernet
            case .wifi: return .wifi
            case .unknown: return .unknown
            case .noNetwork: return .noConnection
            }
        }
        currentNetworkHardwareAddress = { Current.macBridge.networkConnectivity.interface?.hardwareAddress }
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
    }
    #elseif os(iOS)
    init() {
        let reachability = try? Reachability()

        do {
            try reachability?.startNotifier()
        } catch {
            Current.Log.error("failed to start reachability notifier: \(error)")
        }
        hasWiFi = { true }
        currentWiFiSSID = {
            guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
            for interface in interfaces {
                guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? else {
                    continue
                }
                return interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
            }
            return nil
        }
        currentWiFiBSSID = {
            guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
            for interface in interfaces {
                guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? else {
                    continue
                }
                return interfaceInfo[kCNNetworkInfoKeyBSSID as String] as? String
            }
            return nil
        }
        connectivityDidChangeNotification = { .reachabilityChanged }
        simpleNetworkType = { reachability?.getSimpleNetworkType() ?? .unknown }
        cellularNetworkType = { reachability?.getNetworkType() ?? .unknown }
        currentNetworkHardwareAddress = { nil }
        networkAttributes = { [:] }
    }
    #else
    init() {
        hasWiFi = { true }
        currentWiFiSSID = { nil }
        currentWiFiBSSID = { nil }
        connectivityDidChangeNotification = { .init(rawValue: "_noop_") }
        simpleNetworkType = { .unknown }
        cellularNetworkType = { .unknown }
        currentNetworkHardwareAddress = { nil }
        networkAttributes = { [:] }
    }
    #endif

    #if os(iOS) && !targetEnvironment(macCatalyst)
    public var telephonyCarriers: () -> [String: CTCarrier]? = {
        CTTelephonyNetworkInfo().serviceSubscriberCellularProviders
    }
    public var telephonyRadioAccessTechnology: () -> [String: String]? = {
        CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology
    }
    #endif
}
