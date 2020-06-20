import Foundation
import PromiseKit
import CoreLocation

extension WebhookSensor {
    public static func allSensors(
        location: Location?,
        trigger: LocationUpdateTrigger
    ) -> Promise<[WebhookSensor]> {
        firstly { () -> Guarantee<[Result<[WebhookSensor]>]> in
            let allSensors: [Promise<[WebhookSensor]>] = [
                activity(),
                pedometer(),
                battery(),
                connectivity(),
                geocoder(location: location),
                lastUpdate(trigger: trigger)
            ]

            return when(resolved: allSensors)
        }.map { (sensors: [Result<[WebhookSensor]>]) throws -> [WebhookSensor] in
            sensors.compactMap { (result: Result<[WebhookSensor]>) -> [WebhookSensor]? in
                if case .fulfilled(let value) = result {
                    return value
                } else {
                    return nil
                }
            }.flatMap { $0 }
        }
    }
}
