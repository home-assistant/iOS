import Foundation
import PromiseKit
#if os(iOS)
import CoreTelephony
import Reachability
#endif

public class ConnectivitySensor: SensorProvider {
    public enum ConnectivityError: Error {
        case unsupportedPlatform
        case noCarriers
    }

    public let request: SensorProviderRequest
    required public init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        #if os(iOS)
        return firstly {
            when(resolved: [
                ssid(),
                connectionType(),
                cellularProviders()
            ])
        }.map { sensors -> [WebhookSensor] in
            sensors.compactMap { (result: Result<[WebhookSensor]>) -> [WebhookSensor]? in
                if case .fulfilled(let value) = result {
                    return value
                } else {
                    return nil
                }
            }.flatMap { $0 }
        }
        #else
        return .init(error: ConnectivityError.unsupportedPlatform)
        #endif
    }

    #if os(iOS)

    private func ssid() -> Promise<[WebhookSensor]> {
        return .value([
            with(WebhookSensor(name: "SSID", uniqueID: "connectivity_ssid")) { sensor in
                if let ssid = Current.connectivity.currentWiFiSSID() {
                    sensor.State = ssid
                    sensor.Icon = "mdi:wifi"
                } else {
                    sensor.State = "Not Connected"
                    sensor.Icon = "mdi:wifi-off"
                }
            },
            with(WebhookSensor(name: "BSSID", uniqueID: "connectivity_bssid")) { sensor in
                if let bssid = Current.connectivity.currentWiFiBSSID() {
                    sensor.State = bssid
                    sensor.Icon = "mdi:wifi-star"
                } else {
                    sensor.State = "Not Connected"
                    sensor.Icon = "mdi:wifi-off"
                }
            }
        ])
    }

    private func connectionType() -> Promise<[WebhookSensor]> {
        let simple = Current.connectivity.simpleNetworkType()

        return .value([
            with(WebhookSensor(name: "Connection Type", uniqueID: "connectivity_connection_type")) { sensor in
                sensor.State = simple.description
                sensor.Icon = simple.icon

                if case .cellular = simple {
                    let cellular = Current.connectivity.cellularNetworkType()

                    sensor.Attributes = [
                        "Cellular Technology": cellular.description
                    ]
                }
            }
        ])
    }

    private func cellularProviders() -> Promise<[WebhookSensor]> {
        let networkInfo = Current.connectivity.telephonyCarriers()
        let radioTech = Current.connectivity.telephonyRadioAccessTechnology()

        if let networkInfo = networkInfo {
            return when(fulfilled: networkInfo.map {
                carrierSensor(
                    carrier: $0.value,
                    radioTech: radioTech?[$0.key],
                    key: $0.key,
                    hasMultiple: networkInfo.count > 1
                )
            })
        } else {
            return .init(error: ConnectivityError.noCarriers)
        }
    }

    private func carrierSensor(
        carrier: CTCarrier,
        radioTech: String?,
        key: String,
        hasMultiple: Bool
    ) -> Guarantee<WebhookSensor> {
        let sensor: WebhookSensor

        if hasMultiple, let id = key.last {
            // the user has multiple, so break them into numbered
            sensor = WebhookSensor(
                name: "SIM \(id)",
                uniqueID: "connectivity_sim_\(id)",
                icon: "mdi:sim",
                state: "Unknown"
            )
        } else {
            sensor = WebhookSensor(
                name: "Cellular Provider",
                uniqueID: "connectivity_cellular_provider",
                icon: "mdi:sim",
                state: "Unknown"
            )
        }

        sensor.State = carrier.carrierName ?? "N/A"
        sensor.Attributes = [
            "Carrier ID": hasMultiple ? key : "N/A",
            "Carrier Name": carrier.carrierName ?? "N/A",
            "Mobile Country Code": carrier.mobileCountryCode ?? "N/A",
            "Mobile Network Code": carrier.mobileNetworkCode ?? "N/A",
            "ISO Country Code": carrier.isoCountryCode ?? "N/A",
            "Allows VoIP": carrier.allowsVOIP
        ]

        if let radioTech = radioTech {
            sensor.Attributes?["Current Radio Technology"] = Self.getRadioTechName(radioTech)
        }

        return .value(sensor)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func getRadioTechName(_ radioTech: String) -> String? {
        switch radioTech {
        case CTRadioAccessTechnologyGPRS:
            return "General Packet Radio Service (GPRS)"
        case CTRadioAccessTechnologyEdge:
            return "Enhanced Data rates for GSM Evolution (EDGE)"
        case CTRadioAccessTechnologyCDMA1x:
            return "Code Division Multiple Access (CDMA 1X)"
        case CTRadioAccessTechnologyWCDMA:
            return "Wideband Code Division Multiple Access (WCDMA)"
        case CTRadioAccessTechnologyHSDPA:
            return "High Speed Downlink Packet Access (HSDPA)"
        case CTRadioAccessTechnologyHSUPA:
            return "High Speed Uplink Packet Access (HSUPA)"
        case CTRadioAccessTechnologyCDMAEVDORev0:
            return "Code Division Multiple Access Evolution-Data Optimized Revision 0 (CDMA EV-DO Rev. 0)"
        case CTRadioAccessTechnologyCDMAEVDORevA:
            return "Code Division Multiple Access Evolution-Data Optimized Revision A (CDMA EV-DO Rev. A)"
        case CTRadioAccessTechnologyCDMAEVDORevB:
            return "Code Division Multiple Access Evolution-Data Optimized Revision B (CDMA EV-DO Rev. B)"
        case CTRadioAccessTechnologyeHRPD:
            return "High Rate Packet Data (HRPD)"
        case CTRadioAccessTechnologyLTE:
            return "Long-Term Evolution (LTE)"
        default:
            return nil
        }
    }
    #endif
}
