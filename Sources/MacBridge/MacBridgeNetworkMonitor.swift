import CoreWLAN
import Foundation
import SystemConfiguration

class MacBridgeNetworkMonitor {
    static var connectivityDidChangeNotification: Notification.Name = .init("ha_connectivityDidChange")

    private let wifiClient: CWWiFiClient
    private var scStore: SCDynamicStore!
    private var cachedNetworkConnectivity: MacBridgeNetworkConnectivityImpl?
    private static let networkKey = SCDynamicStoreKeyCreateNetworkGlobalEntity(
        nil,
        kSCDynamicStoreDomainState,
        kSCEntNetIPv4
    )

    init() {
        self.wifiClient = CWWiFiClient.shared()

        let callback: SCDynamicStoreCallBack = { _, _, context in
            guard let context = context else { return }
            let this = Unmanaged<MacBridgeNetworkMonitor>.fromOpaque(context).takeUnretainedValue()
            this.storeDidChange()
        }

        var context: SCDynamicStoreContext = .init(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let scStore = SCDynamicStoreCreate(nil, "HAMacBridge" as CFString, callback, &context)!
        SCDynamicStoreSetNotificationKeys(scStore, nil, [Self.networkKey] as CFArray)
        SCDynamicStoreSetDispatchQueue(scStore, DispatchQueue.main)
        self.scStore = scStore
    }

    var networkConnectivity: MacBridgeNetworkConnectivityImpl {
        if let cachedNetworkConnectivity = cachedNetworkConnectivity {
            return cachedNetworkConnectivity
        } else {
            let new = newNetworkConnectivity()
            cachedNetworkConnectivity = new
            return new
        }
    }

    private var currentInterface: SCNetworkInterface? {
        guard let properties = SCDynamicStoreCopyValue(scStore, Self.networkKey) as? [CFString: Any] else {
            return nil
        }

        guard let interfaceName = properties[kSCDynamicStorePropNetPrimaryInterface] as? String,
              let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
            return nil
        }

        guard var interface = interfaces.first(where: {
            SCNetworkInterfaceGetBSDName($0) == interfaceName as CFString
        }) else {
            return nil
        }

        while let next = SCNetworkInterfaceGetInterface(interface) {
            // go down to the leaf node if this is a virtual/layered interface
            interface = next
        }

        return interface
    }

    private func storeDidChange() {
        // we cache mainly so that we don't need to dig into the system to get the values on each access,
        // not because it notifies unnecessarily (it doesn't)
        cachedNetworkConnectivity = newNetworkConnectivity()
        NotificationCenter.default.post(name: Self.connectivityDidChangeNotification, object: nil)
    }

    internal func newNetworkConnectivity() -> MacBridgeNetworkConnectivityImpl {
        let primaryInterface = currentInterface
        let wifiInterfaces = wifiClient.interfaces() ?? []
        let wifi: MacBridgeWiFiImpl? = wifiInterfaces.compactMap { interface -> MacBridgeWiFiImpl? in
            if let ssid = interface.ssid(), let bssid = interface.bssid() {
                return MacBridgeWiFiImpl(ssid: ssid, bssid: bssid)
            } else {
                return nil
            }
        }.first
        let type: MacBridgeNetworkType = {
            if let interfaceType = primaryInterface.flatMap(SCNetworkInterfaceGetInterfaceType) {
                return networkType(for: interfaceType)
            } else {
                return wifi != nil ? .wifi : .noNetwork
            }
        }()
        let interface: MacBridgeNetworkInterfaceImpl? = primaryInterface.flatMap {
            if let localizedName = SCNetworkInterfaceGetLocalizedDisplayName($0),
               let hardwareAddress = SCNetworkInterfaceGetHardwareAddressString($0) {
                return .init(name: localizedName as String, hardwareAddress: hardwareAddress as String)
            } else {
                return nil
            }
        }

        return .init(networkType: type, hasWiFi: !wifiInterfaces.isEmpty, wifi: wifi, interface: interface)
    }

    private func networkType(for interfaceType: CFString) -> MacBridgeNetworkType {
        switch interfaceType {
        case kSCNetworkInterfaceTypeIEEE80211: return .wifi
        case kSCNetworkInterfaceTypeEthernet: return .ethernet
        default: return .unknown
        }
    }
}
