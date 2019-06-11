//
//  WebhookSensors.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/7/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import PromiseKit
import DeviceKit
import CoreMotion
import CoreLocation
import Contacts
import Iconic
#if os(iOS)
import CoreTelephony
import Reachability
#endif

// swiftlint:disable:next type_body_length
public class WebhookSensors {
    public var AllSensors: Promise<[WebhookSensor]> {
        return firstly {
            when(fulfilled: self.Activity, self.Pedometer)
            }.then { activitySensor, pedometerSensors -> Promise<[WebhookSensor]> in
                var allSensors: [WebhookSensor?] = [activitySensor] + self.Battery + pedometerSensors
                #if os(iOS)
                allSensors.append(contentsOf: [self.BSSID, self.ConnectionType,
                                               self.SSID] + self.CellularProviderSensors)
                #endif

                return Promise.value(allSensors.compactMap { $0 })
        }
    }

    public var Battery: [WebhookSensor] {
        var level = Int(Device.current.batteryLevel ?? 0)
        if level == -100 { // simulator fix
            level = 100
        }

        var state = "Unknown"
        var icon = "mdi:battery"

        let batState = Device.current.batteryState ?? Device.BatteryState.full

        switch batState {
        case .charging(let level):
            state = "Charging"
            if level > 10 {
                let rounded = Int(round(Double(level / 20) - 0.01)) * 20
                icon = "mdi:battery-charging-\(rounded)"
            } else {
                icon = "mdi:battery-outline"
            }
        case .unplugged(let level):
            state = "Not Charging"
            if level <= 5 {
                icon = "mdi:battery-alert"
            } else if level > 5 && level < 95 {
                let rounded = Int(round(Double(level / 10) - 0.01)) * 10
                icon = "mdi:battery-\(rounded)"
            }
        case .full:
            state = "Full"
        }

        let levelSensor = WebhookSensor(name: "Battery Level",
                                        uniqueID: "battery_level", icon: .batteryIcon,
                                        deviceClass: .battery, state: level)
        levelSensor.Icon = icon
        levelSensor.Attributes = ["Battery State": state]
        levelSensor.UnitOfMeasurement = "%"
        let stateSensor = WebhookSensor(name: "Battery State",
                                        uniqueID: "battery_state", icon: .batteryIcon,
                                        deviceClass: .battery, state: state)
        stateSensor.Icon = icon
        stateSensor.Attributes = ["Battery Level": level]
        return [levelSensor, stateSensor]
    }

    #if os(iOS)
    // MARK: Connectivity sensors

    public var BSSID: WebhookSensor? {
        let sensor = WebhookSensor(name: "BSSID", uniqueID: "connectivity_bssid", icon: "mdi:wifi-off",
                                   state: "Not Connected")

        if let bssid = ConnectionInfo.CurrentWiFiBSSID {
            sensor.State = bssid
            sensor.Icon = "mdi:wifi-star"
        }
        return sensor
    }

    public var SSID: WebhookSensor? {
        let sensor = WebhookSensor(name: "SSID", uniqueID: "connectivity_ssid", icon: "mdi:wifi-off",
                                   state: "Not Connected")
        if let ssid = ConnectionInfo.CurrentWiFiSSID {
            sensor.State = ssid
            sensor.Icon = "mdi:wifi"
        }
        return sensor
    }

    public var ConnectionType: WebhookSensor {
        let state = Reachability.getSimpleNetworkType()

        let sensor = WebhookSensor(name: "Connection Type",
                                   uniqueID: "connectivity_connection_type", icon: state.icon,
                                   state: state.description)

        if state == .cellular {
            sensor.Attributes = [
                "Cellular Technology": Reachability.getNetworkType().description
            ]
        }

        return sensor
    }

    public var CellularProviderSensors: [WebhookSensor] {
        let networkInfo = CTTelephonyNetworkInfo()

        if let providers = networkInfo.serviceSubscriberCellularProviders {
            let radioTech = networkInfo.serviceCurrentRadioAccessTechnology
            return providers.map { self.makeCarrierSensor($0.value, radioTech?[$0.key], $0.key) }
        }

        return [WebhookSensor]()
    }

    private func makeCarrierSensor(_ carrier: CTCarrier, _ radioTech: String?, _ key: String? = nil) -> WebhookSensor {
        var carrierSensor = WebhookSensor(name: "Cellular Provider", uniqueID: "connectivity_cellular_provider",
                                          icon: "mdi:sim", state: "Unknown")

        if let key = key, let id = key.last {
            carrierSensor = WebhookSensor(name: "SIM \(id)", uniqueID: "connectivity_sim_\(id)", icon: "mdi:sim",
                                          state: "Unknown")
        }

        carrierSensor.State = carrier.carrierName
        carrierSensor.Attributes = [
            "Carrier ID": key ?? "N/A",
            "Carrier Name": carrier.carrierName ?? "N/A",
            "Mobile Country Code": carrier.mobileCountryCode ?? "N/A",
            "Mobile Network Code": carrier.mobileNetworkCode ?? "N/A",
            "ISO Country Code": carrier.isoCountryCode ?? "N/A",
            "Allows VoIP": carrier.allowsVOIP
        ]

        if let radioTech = radioTech {
            carrierSensor.Attributes?["Current Radio Technology"] = getRadioTechName(radioTech)
        }

        return carrierSensor
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func getRadioTechName(_ radioTech: String) -> String? {
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

    // MARK: CMPedometerData sensors

    public var Pedometer: Promise<[WebhookSensor]> {
        return firstly {
            self.getLatestPedometerData()
            }.map { data -> [WebhookSensor?] in
                self.pedometerData = data
                return [self.averageActivePace, self.currentCadence, self.currentPace, self.distance,
                        self.floorsAscended, self.floorsDescended, self.steps]
            }.compactMapValues { $0 }
    }

    private var pedometerData: CMPedometerData?

    private var pedometer = CMPedometer()

    private func getLatestPedometerData() -> Promise<CMPedometerData?> {
        return Promise { seal in
            guard CMPedometer.isStepCountingAvailable() else {
                Current.Log.warning("Step counting is not available")
                return seal.fulfill(nil)
            }

            guard Current.settingsStore.motionEnabled else {
                Current.Log.warning("Motion permission not enabled")
                return seal.fulfill(nil)
            }

            self.pedometer.queryPedometerData(from: Calendar.current.startOfDay(for: Date()),
                                              to: Date(), withHandler: seal.resolve)
        }
    }

    private var distance: WebhookSensor? {
        guard let intVal = self.pedometerData?.distance?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Distance", uniqueID: "pedometer_distance", icon: "mdi:hiking", state: intVal,
                             unit: "m")
    }

    private var floorsAscended: WebhookSensor? {
        guard let intVal = self.pedometerData?.floorsAscended?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Floors Ascended", uniqueID: "pedometer_floors_ascended", icon: "mdi:slope-uphill",
                             state: intVal, unit: "floors")
    }

    private var floorsDescended: WebhookSensor? {
        guard let intVal = self.pedometerData?.floorsDescended?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Floors Descended", uniqueID: "pedometer_floors_descended",
                             icon: "mdi:slope-downhill", state: intVal, unit: "floors")
    }

    private var steps: WebhookSensor? {
        guard let intVal = self.pedometerData?.numberOfSteps.intValue else {
            return nil
        }
        return WebhookSensor(name: "Steps", uniqueID: "pedometer_steps", icon: "mdi:walk", state: intVal, unit: "steps")
    }

    private var averageActivePace: WebhookSensor? {
        guard let intVal = self.pedometerData?.averageActivePace?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Average Active Pace", uniqueID: "pedometer_avg_active_pace",
                             icon: "mdi:speedometer", state: intVal, unit: "m/s")
    }

    private var currentPace: WebhookSensor? {
        guard let intVal = self.pedometerData?.currentPace?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Current Pace", uniqueID: "pedometer_current_pace",
                             icon: "mdi:speedometer", state: intVal, unit: "m/s")
    }

    private var currentCadence: WebhookSensor? {
        guard let intVal = self.pedometerData?.currentCadence?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Current Cadence", uniqueID: "pedometer_current_cadence", state: intVal,
                             unit: "steps/s")
    }

    // MARK: CMMotionActivity sensors

    private func getLatestMotionActivity() -> Promise<[CMMotionActivity]?> {
        return Promise { seal in
            guard CMMotionActivityManager.isActivityAvailable() else {
                Current.Log.warning("Activity is not available")
                return seal.fulfill(nil)
            }

            guard Current.settingsStore.motionEnabled else {
                Current.Log.warning("Motion permission not enabled")
                return seal.fulfill(nil)
            }

            let end = Date()
            let start = Calendar.current.date(byAdding: .minute, value: -10, to: end)!
            let queue = OperationQueue.main
            let manager = CMMotionActivityManager()
            manager.queryActivityStarting(from: start, to: end, to: queue, withHandler: seal.resolve)
        }
    }

    private var Activity: Promise<WebhookSensor?> {
        return firstly {
            self.getLatestMotionActivity()
            }.then { motionActivity -> Promise<WebhookSensor?> in
                guard let activity = motionActivity?.last else {
                    return Promise.value(nil)
                }
                let activitySensor = WebhookSensor(name: "Activity", uniqueID: "activity")
                activitySensor.State = activity.activityTypes.first
                activitySensor.Attributes = [
                    "Confidence": activity.confidence.description,
                    "Types": activity.activityTypes
                ]
                activitySensor.Icon = activity.icons.first
                return Promise.value(activitySensor)
        }
    }

    // MARK: CLPlacemark sensor

    private let geocoder = CLGeocoder()

    private func geocodeLocation(_ locationToGeocode: CLLocation) -> Promise<[CLPlacemark]?> {
        return Promise {
            geocoder.reverseGeocodeLocation(locationToGeocode, completionHandler: $0.resolve)
        }
    }

    public var GeocodedLocationSensorConfig: WebhookSensor {
        let locationSensor = WebhookSensor(name: "Geocoded Location", uniqueID: "geocoded_location")
        locationSensor.State = "Unknown"
        locationSensor.Icon = "mdi:\(MaterialDesignIcons.mapIcon.name)"
        return locationSensor
    }

    public func GeocodedLocationSensor(_ locationToGeocode: CLLocation? = nil) -> Promise<WebhookSensor> {
        let locationSensor = self.GeocodedLocationSensorConfig

        guard let locationToGeocode = locationToGeocode else {
            return Promise.value(locationSensor)
        }

        return firstly {
            self.geocodeLocation(locationToGeocode)
        }.then { results -> Promise<WebhookSensor> in
            guard let placemark = results?.first else {
                return Promise.value(locationSensor)
            }

            locationSensor.State = CNPostalAddressFormatter.string(from: self.parsePlacemarkToPostalAddress(placemark),
                                                                   style: .mailingAddress)

            locationSensor.Attributes = [
                "Administrative Area": placemark.administrativeArea ?? "N/A",
                "Areas Of Interest": placemark.areasOfInterest ?? "N/A",
                "Country": placemark.country ?? "N/A",
                "Inland Water": placemark.inlandWater ?? "N/A",
                "ISO Country Code": placemark.isoCountryCode ?? "N/A",
                "Locality": placemark.locality ?? "N/A",
                "Location": [placemark.location?.coordinate.latitude, placemark.location?.coordinate.longitude],
                "Name": placemark.name ?? "N/A",
                "Ocean": placemark.ocean ?? "N/A",
                "Postal Code": placemark.postalCode ?? "N/A",
                "Sub Administrative Area": placemark.subAdministrativeArea ?? "N/A",
                "Sub Locality": placemark.subLocality ?? "N/A",
                "Sub Thoroughfare": placemark.subThoroughfare ?? "N/A",
                "Thoroughfare": placemark.thoroughfare ?? "N/A",
                "Time Zone": placemark.timeZone?.identifier ?? TimeZone.current.identifier
            ]

            return Promise.value(locationSensor)
        }
    }

    private func parsePlacemarkToPostalAddress(_ placemark: CLPlacemark) -> CNPostalAddress {
        if let address = placemark.postalAddress {
            return address
        }

        let postalAddress = CNMutablePostalAddress()
        postalAddress.street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }           // remove nils, so that...
            .joined(separator: " ")      // ...only if both != nil, add a space.
        postalAddress.city = placemark.locality ?? ""
        postalAddress.state = placemark.administrativeArea ?? ""
        postalAddress.postalCode = placemark.postalCode ?? ""
        postalAddress.country = placemark.country ?? ""
        postalAddress.isoCountryCode = placemark.isoCountryCode ?? ""
        if #available(iOS 10.3, *) {
            postalAddress.subLocality = placemark.subLocality ?? ""
            postalAddress.subAdministrativeArea = placemark.subAdministrativeArea ?? ""
        }

        return postalAddress
    }
// swiftlint:disable:next file_length
}
