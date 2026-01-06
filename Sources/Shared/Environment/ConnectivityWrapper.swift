import Foundation
#if os(iOS)
import CoreTelephony
import Reachability
#endif
import Communicator
import NetworkExtension

/// Real-time network information fetched asynchronously
public struct NetworkInfo: Equatable {
    public let ssid: String?
    public let bssid: String?

    public init(ssid: String?, bssid: String?) {
        self.ssid = ssid
        self.bssid = bssid
    }
}

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

    /// Async method to fetch current WiFi network info in real-time.
    /// This is the preferred method to use for critical operations that need the latest network state.
    public var currentNetworkInfo: () async -> NetworkInfo

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
        // For macCatalyst, we can get the info synchronously from macBridge
        self.currentNetworkInfo = {
            NetworkInfo(
                ssid: Current.macBridge.networkConnectivity.wifi?.ssid,
                bssid: Current.macBridge.networkConnectivity.wifi?.bssid
            )
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
            nil
        }
        self.currentWiFiBSSID = {
            nil
        }
        self.connectivityDidChangeNotification = { .reachabilityChanged }
        self.simpleNetworkType = { reachability?.getSimpleNetworkType() ?? .unknown }
        self.cellularNetworkType = { reachability?.getNetworkType() ?? .unknown }
        self.currentNetworkHardwareAddress = { nil }
        self.networkAttributes = { [:] }

        // Default async implementation that fetches real-time network info
        self.currentNetworkInfo = {
            await Self.fetchNetworkInfo()
        }

        syncNetworkInformation()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectivityDidChange(_:)),
            name: .reachabilityChanged,
            object: nil
        )
    }
    #else
    init() {
        self.hasWiFi = { true }
        self.currentWiFiSSID = {
            let ssid = WatchUserDefaults.shared.string(for: .watchSSID)
            Current.Log.verbose("Watch current WiFi SSID: \(String(describing: ssid))")
            return ssid
        }
        self.currentWiFiBSSID = { nil }
        self.connectivityDidChangeNotification = { .init(rawValue: "_noop_") }
        self.simpleNetworkType = { .unknown }
        self.cellularNetworkType = { .unknown }
        self.currentNetworkHardwareAddress = { nil }
        self.networkAttributes = { [:] }
        // For watchOS, get SSID from user defaults (synced from iOS)
        self.currentNetworkInfo = {
            let ssid = WatchUserDefaults.shared.string(for: .watchSSID)
            return NetworkInfo(ssid: ssid, bssid: nil)
        }
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

    @objc private func connectivityDidChange(_ note: Notification) {
        syncNetworkInformation()
    }

    // TODO: Refactor SSID retrieval to be async instead of hacking around with completion handlers
    public func syncNetworkInformation(completion: (() -> Void)? = nil) {
        #if targetEnvironment(macCatalyst)
        // macOS uses macBridge to retrieve network information
        completion?()
        #else
        NEHotspotNetwork.fetchCurrent { hotspotNetwork in
            Current.Log
                .verbose(
                    "Current SSID: \(String(describing: hotspotNetwork?.ssid)), current BSSID: \(String(describing: hotspotNetwork?.bssid))"
                )
            let ssid = hotspotNetwork?.ssid
            self.currentWiFiSSID = {
                #if targetEnvironment(simulator)
                return "Simulator"
                #endif
                return ssid
            }
            let bssid = hotspotNetwork?.bssid
            self.currentWiFiBSSID = { bssid }
            completion?()
        }
        #endif
    }

    /// Fetches network info asynchronously. This should be used for operations requiring real-time data.
    private static func fetchNetworkInfo() async -> NetworkInfo {
        #if targetEnvironment(macCatalyst)
        return NetworkInfo(
            ssid: Current.macBridge.networkConnectivity.wifi?.ssid,
            bssid: Current.macBridge.networkConnectivity.wifi?.bssid
        )
        #elseif os(iOS)
        return await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { hotspotNetwork in
                #if targetEnvironment(simulator)
                let ssid: String? = "Simulator"
                #else
                let ssid = hotspotNetwork?.ssid
                #endif
                let bssid = hotspotNetwork?.bssid
                Current.Log
                    .verbose("Fetched network info - SSID: \(String(describing: ssid)), BSSID: \(String(describing: bssid))")
                continuation.resume(returning: NetworkInfo(ssid: ssid, bssid: bssid))
            }
        }
        #else
        let ssid = WatchUserDefaults.shared.string(for: .watchSSID)
        return NetworkInfo(ssid: ssid, bssid: nil)
        #endif
    }
}
