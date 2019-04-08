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
import Iconic
#if os(iOS)
import Reachability
#endif

public class WebhookSensors {
    public var AllSensors: Promise<[WebhookSensor]> {
        return firstly {
            when(fulfilled: self.Activity, self.Pedometer)
            }.then { activitySensor, pedometerSensors -> Promise<[WebhookSensor]> in
                var allSensors: [WebhookSensor?] = [self.Battery]
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

    public var Battery: WebhookSensor {
        var batLevel = Int(Device().batteryLevel)
        if batLevel == -100 { // simulator fix
            batLevel = 100
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

        let sensor = WebhookSensor(name: "Battery", uniqueID: "battery", icon: .batteryIcon, deviceClass: .battery,
                                   state: state)
        sensor.Icon = icon
        sensor.Attributes = ["State": state, "Level": batLevel]
        return sensor
    }

    #if os(iOS)
    public var BSSID: WebhookSensor? {
        guard let bssid = ConnectionInfo.currentBSSID() else {
            return nil
        }
        return WebhookSensor(name: "BSSID", uniqueID: "bssid", icon: "mdi:wifi-star", state: bssid)
    }

    public var ConnectionType: WebhookSensor {
        let state = Reachability.getNetworkType()

        return WebhookSensor(name: "Connection Type", uniqueID: "connection_type",
                             icon: state.icon, state: state.description)
    }

    public var SSID: WebhookSensor? {
        guard let ssid = ConnectionInfo.currentSSID() else {
            return nil
        }
        return WebhookSensor(name: "SSID", uniqueID: "ssid", icon: "mdi:wifi", state: ssid)
    }
    #endif

    public var Pedometer: Promise<[WebhookSensor]> {
        return firstly {
            self.getLatestPedometerData()
            }.map { _ -> [WebhookSensor?] in
                return [self.averageActivePace, self.currentCadence, self.currentPace, self.distance,
                        self.floorsAscended, self.floorsDescended, self.steps]
            }.compactMapValues { $0 }
    }

    private var pedometerData: CMPedometerData?

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

    private var pedometer = CMPedometer()

    private var activityManager = CMMotionActivityManager()

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
}
