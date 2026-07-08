import Foundation
#if os(iOS)
import CoreTelephony
#endif
import NetworkExtension

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
    /// Refreshes the cached network information (e.g. current SSID/BSSID), returning once the
    /// values are up to date. Defaults to `syncNetworkInformation()`; replaceable in tests.
    public lazy var refreshNetworkInformation: () async -> Void = { [weak self] in
        await self?.syncNetworkInformation()
    }

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
        let reachability = NetworkReachability()

        self.hasWiFi = { true }
        self.currentWiFiSSID = {
            nil
        }
        self.currentWiFiBSSID = {
            nil
        }
        self.connectivityDidChangeNotification = { NetworkReachability.didChangeNotification }
        self.simpleNetworkType = { reachability.getSimpleNetworkType() }
        self.cellularNetworkType = { reachability.getNetworkType() }
        self.currentNetworkHardwareAddress = { nil }
        self.networkAttributes = { [:] }

        syncNetworkInformation()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectivityDidChange(_:)),
            name: NetworkReachability.didChangeNotification,
            object: nil
        )
    }
    #else
    init() {
        self.hasWiFi = { true }
        self.currentWiFiSSID = { nil }
        self.currentWiFiBSSID = { nil }
        self.connectivityDidChangeNotification = { .init(rawValue: "_noop_") }
        self.simpleNetworkType = { .unknown }
        self.cellularNetworkType = { .unknown }
        self.currentNetworkHardwareAddress = { nil }
        self.networkAttributes = { [:] }

        syncNetworkInformation()
        // Reachability observer is not available for watchOS
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

    public func syncNetworkInformation() async {
        await withCheckedContinuation { continuation in
            syncNetworkInformation {
                continuation.resume()
            }
        }
    }
}
