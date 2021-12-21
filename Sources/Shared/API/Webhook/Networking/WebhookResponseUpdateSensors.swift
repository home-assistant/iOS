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

    func handle(
        request: Promise<WebhookRequest>,
        result: Promise<Any>
    ) -> Guarantee<WebhookResponseHandlerResult> {
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

        let needsRegistering = parsed.map { response in
            response.filter { _, value in
                value.Success == false && value.ErrorCode == "not_registered"
            }.compactMap { value in
                value.key
            }
        }.get { keys in
            if keys.isEmpty == false {
                Current.Log.info("need to register \(keys)")
            }
        }.then { needsRegistering -> Promise<Void> in
            guard needsRegistering.isEmpty == false else {
                return .value(())
            }

            return firstly { () -> Guarantee<[WebhookSensor]> in
                Current.sensors.sensors(reason: .registration, server: api.server).map(\.sensors)
            }.filterValues { sensor in
                if let uniqueID = sensor.UniqueID {
                    return needsRegistering.contains(uniqueID)
                } else {
                    return false
                }
            }.get { sensors in
                Current.Log.info("registering \(sensors.map(\.UniqueID))")
            }.thenMap { sensor in
                Current.webhooks.send(
                    server: api.server,
                    request: .init(type: "register_sensor", data: sensor.toJSON())
                )
            }.asVoid()
        }

        return when(resolved: needsRegistering.asVoid(), parsed.asVoid())
            .map { _ in WebhookResponseHandlerResult.default }
    }

    static func shouldReplace(request current: WebhookRequest, with proposed: WebhookRequest) -> Bool {
        // always replace an existing request with a new one
        true
    }
}
