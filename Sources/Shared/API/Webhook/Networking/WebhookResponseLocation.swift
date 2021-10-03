import Foundation
import ObjectMapper
import PromiseKit
import UserNotifications

extension WebhookResponseIdentifier {
    static var location: Self { .init(rawValue: "updateLocation") }
}

struct WebhookResponseLocationLocalMetadata: ImmutableMappable {
    let trigger: LocationUpdateTrigger
    let zoneName: String

    init(trigger: LocationUpdateTrigger, zone: RLMZone?) {
        self.trigger = trigger
        self.zoneName = zone?.Name ?? "(unknown)"
    }

    init(map: Map) throws {
        self.trigger = try map.value("trigger")
        self.zoneName = try map.value("zone_name")
    }

    func mapping(map: Map) {
        trigger >>> map["trigger"]
        zoneName >>> map["zone_name"]
    }
}

struct WebhookResponseLocation: WebhookResponseHandler {
    let api: HomeAssistantAPI
    init(api: HomeAssistantAPI) {
        self.api = api
    }

    static func localMetdata(
        trigger: LocationUpdateTrigger,
        zone: RLMZone?
    ) -> [String: Any] {
        WebhookResponseLocationLocalMetadata(
            trigger: trigger,
            zone: zone
        ).toJSON()
    }

    static func shouldReplace(request current: WebhookRequest, with proposed: WebhookRequest) -> Bool {
        // recency should always win
        true
    }

    enum HandleError: Error {
        case missingLocalMetadata
    }

    func handle(
        request: Promise<WebhookRequest>,
        result: Promise<Any>
    ) -> Guarantee<WebhookResponseHandlerResult> {
        firstly {
            when(fulfilled: request, result)
        }.map { request, _ in
            guard let localMetadata = request.localMetadata.flatMap({
                Mapper<WebhookResponseLocationLocalMetadata>().map(JSON: $0)
            }) else {
                throw HandleError.missingLocalMetadata
            }

            let notificationOptions = localMetadata.trigger.notificationOptionsFor(zoneName: localMetadata.zoneName)

            Current.clientEventStore.addEvent(ClientEvent(
                text: notificationOptions.body,
                type: .locationUpdate,
                payload: try? request.asDictionary()
            )).cauterize()

            guard notificationOptions.shouldNotify else {
                return nil
            }

            return UNNotificationRequest(
                identifier: notificationOptions.identifier ?? UUID().uuidString,
                content: with(UNMutableNotificationContent()) {
                    $0.title = notificationOptions.title
                    $0.body = notificationOptions.body
                    $0.sound = UNNotificationSound.default
                },
                trigger: nil
            )
        }.recover { _ -> Guarantee<UNNotificationRequest?> in
            // don't send a notification for failed
            .value(nil)
        }.map { notification in
            var result = WebhookResponseHandlerResult.default
            result.notification = notification
            return result
        }
    }
}
