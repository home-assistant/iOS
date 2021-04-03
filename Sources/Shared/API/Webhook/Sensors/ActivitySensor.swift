import CoreMotion
import Foundation
import PromiseKit

public class ActivitySensor: SensorProvider {
    public enum ActivityError: Error {
        case unauthorized
        case unavailable
        case noData
    }

    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        firstly {
            Self.latestMotionActivity()
        }.map { activity in
            with(WebhookSensor(name: "Activity", uniqueID: "activity")) {
                $0.State = activity.activityTypes.first
                $0.Attributes = [
                    "Confidence": activity.confidence.description,
                    "Types": activity.activityTypes,
                ]
                $0.Icon = activity.icons.first
            }
        }.map {
            [$0]
        }
    }

    private static func latestMotionActivity() -> Promise<CMMotionActivity> {
        guard Current.motion.isAuthorized() else {
            return .init(error: ActivityError.unauthorized)
        }

        guard Current.motion.isActivityAvailable() else {
            Current.Log.warning("Activity is not available")
            return .init(error: ActivityError.unavailable)
        }

        let (promise, seal) = Promise<CMMotionActivity>.pending()
        let end = Current.date()
        let start = Current.calendar().date(byAdding: .minute, value: -10, to: end)!
        let queue = OperationQueue.main
        Current.motion.queryStartEndOnQueueHandler(start, end, queue) { activities, error in
            if let latestActivity = activities?.last {
                seal.fulfill(latestActivity)
            } else if let error = error {
                seal.reject(error)
            } else {
                seal.reject(ActivityError.noData)
            }
        }
        return promise
    }
}
