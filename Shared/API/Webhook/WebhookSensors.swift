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
import Reachability
#endif

public class WebhookSensors {
    public var AllSensors: Promise<[WebhookSensor]> {
        return firstly {
            when(fulfilled: self.Activity, self.Pedometer)
            }.then { activitySensor, pedometerSensors -> Promise<[WebhookSensor]> in
                var allSensors: [WebhookSensor?] = self.Battery
                #if os(iOS)
                allSensors.append(contentsOf: [self.BSSID, self.ConnectionType, self.SSID])
                #endif

                allSensors.append(contentsOf: pedometerSensors)

                if let activity = activitySensor {
                    allSensors.append(activity)
                }

                return Promise.value(allSensors.compactMap { $0 })
        }
    }

    public var Battery: [WebhookSensor] {
        var level = Int(Device().batteryLevel)
        if level == -100 { // simulator fix
            level = 100
        }

        var state = "Unknown"
        var icon = "mdi:battery"

        let batState = Device().batteryState

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

        let levelSensor = WebhookSensor(name: "Battery Level", uniqueID: "battery_level", icon: .batteryIcon,
                                        deviceClass: .battery, state: level)
        levelSensor.Icon = icon
        levelSensor.Attributes = ["State": state]

        let stateSensor = WebhookSensor(name: "Battery State", uniqueID: "battery_state", icon: .batteryIcon,
                                        deviceClass: .battery, state: state)
        stateSensor.Icon = icon
        stateSensor.Attributes = ["Level": level]
        return [levelSensor, stateSensor]
    }

    #if os(iOS)
    // MARK: Connectivity sensors

    public var BSSID: WebhookSensor? {
        let sensor = WebhookSensor(name: "BSSID", uniqueID: "bssid", icon: "mdi:wifi-star", state: "Not Connected")
        
        if let bssid = ConnectionInfo.currentBSSID() {
            sensor.State = bssid
        }
        return sensor
    }

    public var SSID: WebhookSensor? {
        let sensor = WebhookSensor(name: "SSID", uniqueID: "ssid", icon: "mdi:wifi", state: "Not Connected")
        if let ssid = ConnectionInfo.currentSSID() {
            sensor.State = ssid
        }
        return sensor
    }

    public var ConnectionType: WebhookSensor {
        let state = Reachability.getSimpleNetworkType()

        let sensor = WebhookSensor(name: "Connection Type", uniqueID: "connection_type", icon: state.icon,
                                   state: state.description)

        if state == .cellular {
            sensor.Attributes = ["Celluar Technology": Reachability.getNetworkType().description]
        }

        return sensor
    }
    #endif

    // MARK: CMPedometerData sensors

    public var Pedometer: Promise<[WebhookSensor]> {
        return firstly {
            self.getLatestPedometerData()
            }.map { _ -> [WebhookSensor?] in
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

        return WebhookSensor(name: "Distance", uniqueID: "distance", state: intVal)
    }

    private var floorsAscended: WebhookSensor? {
        guard let intVal = self.pedometerData?.floorsAscended?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Floors Ascended", uniqueID: "floors_ascended",
                             icon: "mdi:slope-uphill", state: intVal)
    }

    private var floorsDescended: WebhookSensor? {
        guard let intVal = self.pedometerData?.floorsDescended?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Floors Descended", uniqueID: "floors_descended",
                             icon: "mdi:slope-downhill", state: intVal)
    }

    private var steps: WebhookSensor? {
        guard let intVal = self.pedometerData?.numberOfSteps.intValue else {
            return nil
        }
        return WebhookSensor(name: "Steps", uniqueID: "steps", icon: "mdi:walk", state: intVal)
    }

    private var averageActivePace: WebhookSensor? {
        guard let intVal = self.pedometerData?.averageActivePace?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Avg. Active Pace", uniqueID: "avg_active_pace",
                             icon: "mdi:speedometer", state: intVal)
    }

    private var currentPace: WebhookSensor? {
        guard let intVal = self.pedometerData?.currentPace?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Current Pace", uniqueID: "current_pace", icon: "mdi:speedometer", state: intVal)
    }

    private var currentCadence: WebhookSensor? {
        guard let intVal = self.pedometerData?.currentCadence?.intValue else {
            return nil
        }

        return WebhookSensor(name: "Current Cadence", uniqueID: "current_cadence", state: intVal)
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
                let activitySensor = WebhookSensor(name: "Activity", uniqueID: "activity")
                activitySensor.State = activity.activityTypes.first
                activitySensor.Attributes = ["Confidence": activity.confidence.description,
                                             "Types": activity.activityTypes]
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
                "AdministrativeArea": placemark.administrativeArea ?? "N/A",
                "AreasOfInterest": placemark.areasOfInterest ?? "N/A",
                "Country": placemark.country ?? "N/A",
                "InlandWater": placemark.inlandWater ?? "N/A",
                "ISOCountryCode": placemark.isoCountryCode ?? "N/A",
                "Locality": placemark.locality ?? "N/A",
                "Location": [placemark.location?.coordinate.latitude, placemark.location?.coordinate.longitude],
                "Name": placemark.name ?? "N/A",
                "Ocean": placemark.ocean ?? "N/A",
                "PostalCode": placemark.postalCode ?? "N/A",
                "SubAdministrativeArea": placemark.subAdministrativeArea ?? "N/A",
                "SubLocality": placemark.subLocality ?? "N/A",
                "SubThoroughfare": placemark.subThoroughfare ?? "N/A",
                "Thoroughfare": placemark.thoroughfare ?? "N/A",
                "TimeZone": placemark.timeZone?.identifier ?? TimeZone.current.identifier
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
}
