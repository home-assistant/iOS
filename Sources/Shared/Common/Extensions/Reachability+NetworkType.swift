import Foundation
#if os(iOS)
import CoreTelephony
import Network
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
        if [CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA].contains(radioTech) {
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
public final class NetworkReachability {
    public static let didChangeNotification = Notification.Name("NetworkReachabilityChanged")

    private enum Connection: Equatable {
        case unavailable
        case wifi
        case ethernet
        case cellular
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "io.home-assistant.reachability")
    private var lastConnection: Connection?

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connection = Self.connection(for: path)
            guard connection != lastConnection else { return }
            self.lastConnection = connection
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NetworkReachability.didChangeNotification, object: nil)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private static func connection(for path: NWPath) -> Connection {
        guard path.status == .satisfied else { return .unavailable }
        if path.usesInterfaceType(.cellular) {
            return .cellular
        }
        if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .wifi
    }

    private var connection: Connection {
        Self.connection(for: monitor.currentPath)
    }

    public func getSimpleNetworkType() -> NetworkType {
        switch connection {
        case .unavailable:
            return .noConnection
        case .wifi:
            return .wifi
        case .ethernet:
            return .ethernet
        case .cellular:
            return .cellular
        }
    }

    public func getNetworkType() -> NetworkType {
        switch connection {
        case .unavailable:
            return .noConnection
        case .wifi:
            return .wifi
        case .ethernet:
            return .ethernet
        case .cellular:
            #if !targetEnvironment(macCatalyst)
            return Self.getWWANNetworkType()
            #else
            return .cellular
            #endif
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
