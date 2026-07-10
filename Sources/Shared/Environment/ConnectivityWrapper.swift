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

    /// Maximum time to await a network-info fetch before falling back to the last-known state.
    /// Overridable in tests.
    var networkFetchTimeout: TimeInterval = 3

    /// The underlying network-info fetch, before the timeout guard in `fetchNetworkState()`.
    /// Overridable in tests to simulate a fetch that never completes.
    lazy var performNetworkStateFetch: () async -> NetworkState = { [weak self] in
        await self?.systemNetworkStateFetch() ?? NetworkState()
    }

    func fetchNetworkState() async -> NetworkState {
        let fetch = performNetworkStateFetch
        let timeout = networkFetchTimeout
        let fetched: NetworkState? = await withCheckedContinuation { continuation in
            let lock = NSLock()
            var didResume = false
            let resume: (NetworkState?) -> Void = { value in
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            Task { await resume(fetch()) }
            // The timeout must run on GCD, not on a `Task`: the scenario it guards against is the
            // fetch hanging because Swift concurrency's shared thread pool is starved (seen during
            // background launches), and a `Task.sleep`-based timeout would be starved with it.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                resume(nil)
            }
        }

        guard let state = fetched else {
            Current.Log.error(
                "network information fetch timed out after \(timeout)s; keeping last-known network state"
            )
            return readLastKnownNetworkState()
        }

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

    private func systemNetworkStateFetch() async -> NetworkState {
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

    private func systemNetworkStateFetch() async -> NetworkState {
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

        observeConnectivityChanges()
        // Reachability observer is not available for watchOS
    }

    private func systemNetworkStateFetch() async -> NetworkState {
        // The watch has no network information of its own (the phone-synced SSID was removed).
        NetworkState()
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
        // Touch the lazy closures while init is still single-threaded: `lazy var` initialization
        // is not thread-safe, and at app launch these are first hit concurrently from many tasks.
        _ = currentNetworkState
        _ = refreshNetworkInformation
        _ = lastKnownNetworkState
        _ = performNetworkStateFetch

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
