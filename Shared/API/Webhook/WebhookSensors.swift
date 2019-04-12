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
        var level = Int(Device().batteryLevel)
        if level == -100 { // simulator fix
            level = 100
        }

        var state = L10n.Sensors.unknownState
        var icon = "mdi:battery"

        let batState = Device().batteryState

        switch batState {
        case .charging(let level):
            state = L10n.Sensors.Battery.State.charging
            if level > 10 {
                let rounded = Int(round(Double(level / 20) - 0.01)) * 20
                icon = "mdi:battery-charging-\(rounded)"
            } else {
                icon = "mdi:battery-outline"
            }
        case .unplugged(let level):
            state = L10n.Sensors.Battery.State.notCharging
            if level <= 5 {
                icon = "mdi:battery-alert"
            } else if level > 5 && level < 95 {
                let rounded = Int(round(Double(level / 10) - 0.01)) * 10
                icon = "mdi:battery-\(rounded)"
            }
        case .full:
            state = L10n.Sensors.Battery.State.full
        }

        let levelSensor = WebhookSensor(name: L10n.Sensors.BatteryLevel.name,
                                        uniqueID: "battery_level", icon: .batteryIcon,
                                        deviceClass: .battery, state: level)
        levelSensor.Icon = icon
        levelSensor.Attributes = [L10n.Sensors.Battery.Attributes.state: state]
        levelSensor.UnitOfMeasurement = "%"
        let stateSensor = WebhookSensor(name: L10n.Sensors.BatteryState.name,
                                        uniqueID: "battery_state", icon: .batteryIcon,
                                        deviceClass: .battery, state: state)
        stateSensor.Icon = icon
        stateSensor.Attributes = [L10n.Sensors.Battery.Attributes.level: level]
        return [levelSensor, stateSensor]
    }

    #if os(iOS)
    // MARK: Connectivity sensors

    public var BSSID: WebhookSensor? {
        let sensor = WebhookSensor(name: L10n.Sensors.Bssid.name, uniqueID: "connectivity_bssid", icon: "mdi:wifi-star",
                                   state: L10n.Sensors.Connectivity.notConnected)

        if let bssid = ConnectionInfo.currentBSSID() {
            sensor.State = bssid
        }
        return sensor
    }

    public var SSID: WebhookSensor? {
        let sensor = WebhookSensor(name: L10n.Sensors.Ssid.name, uniqueID: "connectivity_ssid", icon: "mdi:wifi",
                                   state: L10n.Sensors.Connectivity.notConnected)
        if let ssid = ConnectionInfo.currentSSID() {
            sensor.State = ssid
        }
        return sensor
    }

    public var ConnectionType: WebhookSensor {
        let state = Reachability.getSimpleNetworkType()

        let sensor = WebhookSensor(name: L10n.Sensors.ConnectionType.name,
                                   uniqueID: "connectivity_connection_type", icon: state.icon,
                                   state: state.description)

        if state == .cellular {
            sensor.Attributes = [
                L10n.Sensors.ConnectionType.Attributes.cellTechType: Reachability.getNetworkType().description
            ]
        }

        return sensor
    }

    public var CellularProviderSensors: [WebhookSensor] {
        let networkInfo = CTTelephonyNetworkInfo()

        if #available(iOS 12.0, *), let providers = networkInfo.serviceSubscriberCellularProviders {
            let radioTech = networkInfo.serviceCurrentRadioAccessTechnology
            return providers.map { self.makeCarrierSensor($0.value, radioTech?[$0.key], $0.key) }
        } else if let provider = networkInfo.subscriberCellularProvider {
            return [self.makeCarrierSensor(provider, networkInfo.currentRadioAccessTechnology)]
        }

        return [WebhookSensor]()
    }

    private func makeCarrierSensor(_ carrier: CTCarrier,
                                   _ radioTech: String?,
                                   _ key: String? = nil) -> WebhookSensor {
        var carrierSensor = WebhookSensor(name: L10n.Sensors.CellularProvider.name(""),
                                          uniqueID: "connectivity_cellular_provider",
                                          icon: "mdi:signal", state: L10n.Sensors.unknownState)

        if let key = key {
            carrierSensor = WebhookSensor(name: L10n.Sensors.CellularProvider.name(" \(key)"),
                uniqueID: "connectivity_cellular_provider_\(key)", icon: "mdi:signal", state: L10n.Sensors.unknownState)
        }

        carrierSensor.State = carrier.carrierName
        carrierSensor.Attributes = [
            L10n.Sensors.CellularProvider.Attributes.carrierId: key ?? L10n.Sensors.notAvailableState,
            // swiftlint:disable line_length
            L10n.Sensors.CellularProvider.Attributes.carrierName: carrier.carrierName ?? L10n.Sensors.notAvailableState,
            L10n.Sensors.CellularProvider.Attributes.mobileCountryCode: carrier.mobileCountryCode ?? L10n.Sensors.notAvailableState,
            L10n.Sensors.CellularProvider.Attributes.mobileNetworkCode: carrier.mobileNetworkCode ?? L10n.Sensors.notAvailableState,
            L10n.Sensors.CellularProvider.Attributes.isoCountryCode: carrier.isoCountryCode ?? L10n.Sensors.notAvailableState,
            // swiftlint:enable line_length
            L10n.Sensors.CellularProvider.Attributes.allowsVoip: carrier.allowsVOIP
        ]

        if let radioTech = radioTech {
            carrierSensor.Attributes?[L10n.Sensors.CellularProvider.Attributes.radioTech] = getRadioTechName(radioTech)
        }

        return carrierSensor
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func getRadioTechName(_ radioTech: String) -> String? {
        switch radioTech {
        case CTRadioAccessTechnologyGPRS:
            return L10n.Sensors.CellularProvider.RadioTech.gprs
        case CTRadioAccessTechnologyEdge:
            return L10n.Sensors.CellularProvider.RadioTech.edge
        case CTRadioAccessTechnologyCDMA1x:
            return L10n.Sensors.CellularProvider.RadioTech.cdma1x
        case CTRadioAccessTechnologyWCDMA:
            return L10n.Sensors.CellularProvider.RadioTech.wcdma
        case CTRadioAccessTechnologyHSDPA:
            return L10n.Sensors.CellularProvider.RadioTech.hsdpa
        case CTRadioAccessTechnologyHSUPA:
            return L10n.Sensors.CellularProvider.RadioTech.hsupa
        case CTRadioAccessTechnologyCDMAEVDORev0:
            return L10n.Sensors.CellularProvider.RadioTech.cdmaEvdoRev0
        case CTRadioAccessTechnologyCDMAEVDORevA:
            return L10n.Sensors.CellularProvider.RadioTech.cdmaEvdoRevA
        case CTRadioAccessTechnologyCDMAEVDORevB:
            return L10n.Sensors.CellularProvider.RadioTech.cdmaEvdoRevB
        case CTRadioAccessTechnologyeHRPD:
            return L10n.Sensors.CellularProvider.RadioTech.ehrpd
        case CTRadioAccessTechnologyLTE:
            return L10n.Sensors.CellularProvider.RadioTech.lte
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

            var startDate = Calendar.current.startOfDay(for: Date())

            if let lastEntry = Current.realm().objects(LocationHistoryEntry.self).sorted(byKeyPath: "CreatedAt").last {
                startDate = lastEntry.CreatedAt
            }
            self.pedometer.queryPedometerData(from: startDate, to: Date(), withHandler: seal.resolve)
        }
    }

    private var distance: WebhookSensor? {
        guard let intVal = self.pedometerData?.distance?.intValue else {
            return nil
        }

        return WebhookSensor(name: L10n.Sensors.Pedometer.Distance.name,
                             uniqueID: "pedometer_distance", state: intVal, unit: "m")
    }

    private var floorsAscended: WebhookSensor? {
        guard let intVal = self.pedometerData?.floorsAscended?.intValue else {
            return nil
        }

        return WebhookSensor(name: L10n.Sensors.Pedometer.FloorsAscended.name, uniqueID: "pedometer_floors_ascended",
                             icon: "mdi:slope-uphill", state: intVal)
    }

    private var floorsDescended: WebhookSensor? {
        guard let intVal = self.pedometerData?.floorsDescended?.intValue else {
            return nil
        }

        return WebhookSensor(name: L10n.Sensors.Pedometer.FloorsDescended.name, uniqueID: "pedometer_floors_descended",
                             icon: "mdi:slope-downhill", state: intVal)
    }

    private var steps: WebhookSensor? {
        guard let intVal = self.pedometerData?.numberOfSteps.intValue else {
            return nil
        }
        return WebhookSensor(name: L10n.Sensors.Pedometer.Steps.name,
                             uniqueID: "pedometer_steps", icon: "mdi:walk", state: intVal)
    }

    private var averageActivePace: WebhookSensor? {
        guard let intVal = self.pedometerData?.averageActivePace?.intValue else {
            return nil
        }

        return WebhookSensor(name: L10n.Sensors.Pedometer.AverageActivePace.name, uniqueID: "pedometer_avg_active_pace",
                             icon: "mdi:speedometer", state: intVal, unit: L10n.Sensors.Pedometer.Unit.metersPerSecond)
    }

    private var currentPace: WebhookSensor? {
        guard let intVal = self.pedometerData?.currentPace?.intValue else {
            return nil
        }

        return WebhookSensor(name: L10n.Sensors.Pedometer.CurrentPace.name, uniqueID: "pedometer_current_pace",
                             icon: "mdi:speedometer", state: intVal, unit: L10n.Sensors.Pedometer.Unit.metersPerSecond)
    }

    private var currentCadence: WebhookSensor? {
        guard let intVal = self.pedometerData?.currentCadence?.intValue else {
            return nil
        }

        return WebhookSensor(name: L10n.Sensors.Pedometer.CurrentCadence.name,
                             uniqueID: "pedometer_current_cadence", state: intVal,
                             unit: L10n.Sensors.Pedometer.Unit.stepsPerSecond)
    }

    // MARK: CMMotionActivity sensors

    private var activityManager = CMMotionActivityManager()

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
            self.activityManager.queryActivityStarting(from: start, to: end, to: queue, withHandler: seal.resolve)
        }
    }

    private var Activity: Promise<WebhookSensor?> {
        return firstly {
            self.getLatestMotionActivity()
            }.then { motionActivity -> Promise<WebhookSensor?> in
                guard let activity = motionActivity?.last else {
                    return Promise.value(nil)
                }
                let activitySensor = WebhookSensor(name: L10n.Sensors.Activity.name, uniqueID: "activity")
                activitySensor.State = activity.activityTypes.first
                activitySensor.Attributes = [
                    L10n.Sensors.Activity.Attributes.confidence: activity.confidence.description,
                    L10n.Sensors.Activity.Attributes.types: activity.activityTypes
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
        let locationSensor = WebhookSensor(name: L10n.Sensors.GeocodedLocation.name, uniqueID: "geocoded_location")
        locationSensor.State = L10n.Sensors.unknownState
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
                // swiftlint:disable line_length
                L10n.Sensors.GeocodedLocation.Attributes.administrativeArea: placemark.administrativeArea ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.areasOfInterest: placemark.areasOfInterest ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.country: placemark.country ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.inlandWater: placemark.inlandWater ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.isoCountryCode: placemark.isoCountryCode ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.locality: placemark.locality ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.location: [placemark.location?.coordinate.latitude, placemark.location?.coordinate.longitude],
                L10n.Sensors.GeocodedLocation.Attributes.name: placemark.name ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.ocean: placemark.ocean ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.postalCode: placemark.postalCode ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.subAdministrativeArea: placemark.subAdministrativeArea ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.subLocality: placemark.subLocality ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.subThoroughfare: placemark.subThoroughfare ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.thoroughfare: placemark.thoroughfare ?? L10n.Sensors.notAvailableState,
                L10n.Sensors.GeocodedLocation.Attributes.timeZone: placemark.timeZone?.identifier ?? TimeZone.current.identifier
                // swiftlint:enable line_length
            ]

            return Promise.value(locationSensor)
        }
    }

    private func parsePlacemarkToPostalAddress(_ placemark: CLPlacemark) -> CNPostalAddress {
        if #available(iOS 11.0, watchOS 4.0, *), let address = placemark.postalAddress {
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
