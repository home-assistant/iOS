import Foundation
#if os(iOS)
import CoreTelephony
#endif
import NetworkExtension

/// A snapshot of the network information (Wi-Fi and interface details) available to the app.
public struct NetworkState: Equatable {
    /// The SSID of the Wi-Fi network the device is currently connected to, if any.
    public var ssid: String?
    /// The BSSID of the Wi-Fi network the device is currently connected to, if any.
    public var bssid: String?
    /// The hardware (MAC) address of the active network interface, if available (macOS only).
    public var hardwareAddress: String?

    public init(ssid: String? = nil, bssid: String? = nil, hardwareAddress: String? = nil) {
        self.ssid = ssid
        self.bssid = bssid
        self.hardwareAddress = hardwareAddress
    }
}

/// Wrapper around CoreTelephony, Reachability
///
/// Network information (SSID, BSSID, hardware address) is only available asynchronously, so all
/// accessors for it are async and fetch fresh values. `lastKnownNetworkState()` is the single
/// escape hatch for consumers that cannot be async (e.g. HAKit's `connectionInfo` closure).
public class ConnectivityWrapper {
    public var connectivityDidChangeNotification: () -> Notification.Name
    public var hasWiFi: () -> Bool
    public var simpleNetworkType: () -> NetworkType
    public var cellularNetworkType: () -> NetworkType
    public var networkAttributes: () -> [String: Any]

    /// Fetches up-to-date network information (SSID, BSSID, hardware address); replaceable in tests.
    ///
    /// The default implementation always performs a fresh fetch — coalescing onto an in-flight
    /// fetch could return state older than the event that triggered the call — and records the
    /// result as the last-known network state.
    public lazy var currentNetworkState: () async -> NetworkState = { [weak self] in
        await self?.fetchNetworkState() ?? NetworkState()
    }

    /// Refreshes the cached network information, returning once `lastKnownNetworkState()` is up to
    /// date; replaceable in tests.
    public lazy var refreshNetworkInformation: () async -> Void = { [weak self] in
        guard let self else { return }
        let state = await currentNetworkState()
        updateLastKnownNetworkState(state)
    }

    /// The most recently fetched network information, without refreshing it.
    ///
    /// Only meant for consumers that cannot be async — currently the synchronous
    /// `ConnectionInfo.evaluateActiveURL()` core used by HAKit's `connectionInfo` closure and the
    /// Alamofire request adapter. Everything else should use `currentNetworkState()` or
    /// `refreshNetworkInformation()` followed by the relevant async API.
    public lazy var lastKnownNetworkState: () -> NetworkState = { [weak self] in
        self?.readLastKnownNetworkState() ?? NetworkState()
    }

    /// The SSID of the Wi-Fi network the device is currently connected to, freshly fetched.
    public func currentWiFiSSID() async -> String? {
        await currentNetworkState().ssid
    }

    /// The BSSID of the Wi-Fi network the device is currently connected to, freshly fetched.
    public func currentWiFiBSSID() async -> String? {
        await currentNetworkState().bssid
    }

    /// The hardware (MAC) address of the active network interface, freshly fetched (macOS only).
    public func currentNetworkHardwareAddress() async -> String? {
        await currentNetworkState().hardwareAddress
    }

    private let stateLock = NSLock()
    private var cachedNetworkState = NetworkState()

    public func updateLastKnownNetworkState(_ state: NetworkState) {
        stateLock.lock()
        defer { stateLock.unlock() }
        cachedNetworkState = state
    }

    private func readLastKnownNetworkState() -> NetworkState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return cachedNetworkState
    }

    private func fetchNetworkState() async -> NetworkState {
        let state = await performNetworkStateFetch()
        updateLastKnownNetworkState(state)
        return state
    }

    #if targetEnvironment(macCatalyst)
    init() {
        self.hasWiFi = { Current.macBridge.networkConnectivity.hasWiFi }
        self.connectivityDidChangeNotification = { Current.macBridge.networkConnectivityDidChangeNotification }
        self.simpleNetworkType = {
            switch Current.macBridge.networkConnectivity.networkType {
            case .ethernet: return .ethernet
            case .wifi: return .wifi
            case .unknown: return .unknown
            case .noNetwork: return .noConnection
            }
        }
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

        // macBridge network information is always current, so synchronous consumers read it live
        // instead of going through the cached state.
        self.lastKnownNetworkState = {
            let connectivity = Current.macBridge.networkConnectivity
            return NetworkState(
                ssid: connectivity.wifi?.ssid,
                bssid: connectivity.wifi?.bssid,
                hardwareAddress: connectivity.interface?.hardwareAddress
            )
        }

        observeConnectivityChanges()
    }

    private func performNetworkStateFetch() async -> NetworkState {
        // macOS uses macBridge to retrieve network information, which is always current.
        let connectivity = Current.macBridge.networkConnectivity
        return NetworkState(
            ssid: connectivity.wifi?.ssid,
            bssid: connectivity.wifi?.bssid,
            hardwareAddress: connectivity.interface?.hardwareAddress
        )
    }

    #elseif os(iOS)
    init() {
        let reachability = NetworkReachability()

        self.hasWiFi = { true }
        self.connectivityDidChangeNotification = { NetworkReachability.didChangeNotification }
        self.simpleNetworkType = { reachability.getSimpleNetworkType() }
        self.cellularNetworkType = { reachability.getNetworkType() }
        self.networkAttributes = { [:] }

        observeConnectivityChanges()
    }

    private func performNetworkStateFetch() async -> NetworkState {
        let hotspotNetwork = await withCheckedContinuation { (continuation: CheckedContinuation<
            NEHotspotNetwork?,
            Never
        >) in
            NEHotspotNetwork.fetchCurrent { hotspotNetwork in
                continuation.resume(returning: hotspotNetwork)
            }
        }
        Current.Log.verbose(
            "Current SSID: \(String(describing: hotspotNetwork?.ssid)), current BSSID: \(String(describing: hotspotNetwork?.bssid))"
        )
        #if targetEnvironment(simulator)
        let ssid: String? = "Simulator"
        #else
        let ssid = hotspotNetwork?.ssid
        #endif
        return NetworkState(ssid: ssid, bssid: hotspotNetwork?.bssid)
    }

    #else
    init() {
        self.hasWiFi = { true }
        self.connectivityDidChangeNotification = { .init(rawValue: "_noop_") }
        self.simpleNetworkType = { .unknown }
        self.cellularNetworkType = { .unknown }
        self.networkAttributes = { [:] }

        // The watch's network information lives in UserDefaults (synced from the phone), which is
        // always current, so synchronous consumers read it live instead of going through the
        // cached state.
        self.lastKnownNetworkState = {
            NetworkState(ssid: WatchUserDefaults.shared.string(for: .watchSSID))
        }

        observeConnectivityChanges()
        // Reachability observer is not available for watchOS
    }

    private func performNetworkStateFetch() async -> NetworkState {
        let ssid = WatchUserDefaults.shared.string(for: .watchSSID)
        Current.Log.verbose("Watch current WiFi SSID: \(String(describing: ssid))")
        return NetworkState(ssid: ssid)
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

    private func observeConnectivityChanges() {
        // Prime the last-known network state so synchronous consumers have a value early.
        Task { [weak self] in
            await self?.refreshNetworkInformation()
        }

        #if os(iOS) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectivityDidChange(_:)),
            name: NetworkReachability.didChangeNotification,
            object: nil
        )
        #endif
    }

    @objc private func connectivityDidChange(_ note: Notification) {
        Task { [weak self] in
            await self?.refreshNetworkInformation()
        }
    }
}
