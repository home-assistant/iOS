import Foundation
import PromiseKit

extension WebhookResponseIdentifier {
    static var updateSensors: Self { .init(rawValue: "updateSensors") }
}

struct WebhookResponseUpdateSensors: WebhookResponseHandler {
    enum UpdateSensorsError: Error {
        case invalidResponse
    }

    let api: HomeAssistantAPI
    init(api: HomeAssistantAPI) {
        self.api = api
    }

    func handle(result: Promise<Any>) -> Guarantee<WebhookResponseHandlerResult> {
        let parsed = result.map { (possible: Any) throws -> [String: [String: Any]] in
            if let value = possible as? [String: [String: Any]] {
                return value
            } else {
                throw UpdateSensorsError.invalidResponse
            }
        }.map {
            $0.compactMapValues { json -> WebhookSensorResponse? in
                if let response = WebhookSensorResponse(JSON: json) {
                    return response
                } else {
                    Current.Log.warning("failed to parse sensor response: \(json)")
                    return nil
                }
            }
        }

        let needsRegistering = parsed.map {
            $0.filter { _, value in
                value.Success == false && value.ErrorCode == "not_registered"
            }.compactMap { $0.key }
        }.get { keys in
            Current.Log.info("need to register \(keys)")
        }.then { [api] needsRegistering in
            firstly { () -> Guarantee<[WebhookSensor]> in
                api.sensors.sensors(request: .init(reason: .registration))
            }.filterValues { sensor -> Bool in
                needsRegistering.contains(sensor.UniqueID)
            }.get { sensors in
                Current.Log.info("registering \(sensors.map { $0.UniqueID })")
            }.thenMap { sensor in
                api.webhookManager.send(request: .init(type: "register_sensor", data: sensor.toJSON()))
            }
        }

        return when(resolved: needsRegistering.asVoid(), parsed.asVoid())
            .map { _ in WebhookResponseHandlerResult.default }
    }

    static func shouldReplace(request current: URLSessionTask, with proposed: URLSessionTask) -> Bool {
        // always replace an existing request with a new one
        return true
    }
}
