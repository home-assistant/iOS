//
//  HomeAssistantAPI+Location.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 9/16/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Crashlytics
import CoreLocation
import Foundation
import ObjectMapper
import PromiseKit
import Shared

extension HomeAssistantAPI {
    public func submitLocation(updateType: LocationUpdateTrigger,
                               location: CLLocation?,
                               zone: RLMZone?) -> Promise<Void> {
        UIDevice.current.isBatteryMonitoringEnabled = true

        let payload = DeviceTrackerSee(trigger: updateType, location: location, zone: zone)
        payload.Trigger = updateType

        let isBeaconUpdate = (updateType == .BeaconRegionEnter || updateType == .BeaconRegionExit)

        payload.Battery = Float.maximum(0, UIDevice.current.batteryLevel)
        payload.DeviceID = Current.settingsStore.deviceID
        payload.Hostname = UIDevice.current.name
        payload.SourceType = (isBeaconUpdate ? .BluetoothLowEnergy : .GlobalPositioningSystem)

        var jsonPayload = "{\"missing\": \"payload\"}"
        if let p = payload.toJSONString(prettyPrint: false) {
            jsonPayload = p
        }

        let payloadDict: [String: Any] = Mapper<DeviceTrackerSee>().toJSON(payload)

        UIDevice.current.isBatteryMonitoringEnabled = false

        let realm = Current.realm()
        // swiftlint:disable:next force_try
        try! realm.write {
            realm.add(LocationHistoryEntry(updateType: updateType, location: payload.cllocation,
                                           zone: zone, payload: jsonPayload))
        }

        let promise = firstly {
            self.identifyDevice()
            }.then {_ in
                self.callService(domain: "device_tracker", service: "see", serviceData: payloadDict,
                                 shouldLog: true)
            }.done { _ in
                print("Device seen!")
                self.sendLocalNotification(withZone: zone, updateType: updateType, payloadDict: payloadDict)
        }

        promise.catch { err in
            print("Error when updating location!", err)
            Crashlytics.sharedInstance().recordError(err as NSError)
        }

        return promise
    }

    public func getAndSendLocation(trigger: LocationUpdateTrigger?) -> Promise<Void> {
        var updateTrigger: LocationUpdateTrigger = .Manual
        if let trigger = trigger {
            updateTrigger = trigger
        }
        print("getAndSendLocation called via", String(describing: updateTrigger))

        return Promise { seal in
            Current.isPerformingSingleShotLocationQuery = true
            self.oneShotLocationManager = OneShotLocationManager { location, error in
                guard let location = location else {
                    seal.reject(error ?? HomeAssistantAPIError.unknown)
                    return
                }

                Current.isPerformingSingleShotLocationQuery = true
                firstly {
                    self.submitLocation(updateType: updateTrigger, location: location, zone: nil)
                }.done { _ in
                    seal.fulfill(())
                }.catch { error in
                    seal.reject(error)
                }
            }
        }
    }
}
