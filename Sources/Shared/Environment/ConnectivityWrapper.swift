import Foundation
#if os(iOS)
import CoreTelephony
import Reachability
import SystemConfiguration.CaptiveNetwork
#endif
import Communicator

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
        self.hasWiFi = { Current.macBridge.networkConnectivity.hasWiFi }
        self.currentWiFiSSID = { Current.macBridge.networkConnectivity.wifi?.ssid }
        self.currentWiFiBSSID = { Current.macBridge.networkConnectivity.wifi?.bssid }
        self.connectivityDidChangeNotification = { Current.macBridge.networkConnectivityDidChangeNotification }
        self.simpleNetworkType = {
            switch Current.macBridge.networkConnectivity.networkType {
            case .ethernet: return .ethernet
            case .wifi: return .wifi
            case .unknown: return .unknown
            case .noNetwork: return .noConnection
            }
        }
        self.currentNetworkHardwareAddress = { Current.macBridge.networkConnectivity.interface?.hardwareAddress }
        self.cellularNetworkType = { .unknown }
        self.networkAttributes = {
            if let interface = Current.macBridge.networkConnectivity.interface {
                return [
                    "Name": interface.name,
                    "Hardware Address": interface.hardwareAddress,
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
        self.hasWiFi = { true }
        self.currentWiFiSSID = {
            #if targetEnvironment(simulator)
            return "Simulator"
            #endif

            guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
            for interface in interfaces {
                guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? else {
                    continue
                }
                return interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
            }
            return nil
        }
        self.currentWiFiBSSID = {
            guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
            for interface in interfaces {
                guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? else {
                    continue
                }
                return interfaceInfo[kCNNetworkInfoKeyBSSID as String] as? String
            }
            return nil
        }
        self.connectivityDidChangeNotification = { .reachabilityChanged }
        self.simpleNetworkType = { reachability?.getSimpleNetworkType() ?? .unknown }
        self.cellularNetworkType = { reachability?.getNetworkType() ?? .unknown }
        self.currentNetworkHardwareAddress = { nil }
        self.networkAttributes = { [:] }
    }
    #else
    init() {
        self.hasWiFi = { true }
        self.currentWiFiSSID = { Communicator.shared.mostRecentlyReceievedContext.content["SSID"] as? String }
        self.currentWiFiBSSID = { nil }
        self.connectivityDidChangeNotification = { .init(rawValue: "_noop_") }
        self.simpleNetworkType = { .unknown }
        self.cellularNetworkType = { .unknown }
        self.currentNetworkHardwareAddress = { nil }
        self.networkAttributes = { [:] }
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
