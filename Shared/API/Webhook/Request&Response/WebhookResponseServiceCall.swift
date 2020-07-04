import Foundation
import UserNotifications
import PromiseKit

extension WebhookResponseIdentifier {
    static var serviceCall: Self { .init(rawValue: "serviceCall") }
}

struct WebhookResponseServiceCall: WebhookResponseHandler {
    let api: HomeAssistantAPI
    init(api: HomeAssistantAPI) {
        self.api = api
    }

    static func shouldReplace(request current: URLSessionTask, with proposed: URLSessionTask) -> Bool {
        // every service call is distinct
        return false
    }

    func handle(result: Promise<Any>) -> Guarantee<WebhookResponseHandlerResult> {
        result.tap { _ in
            let event = ClientEvent(
                text: "Calling service: TODO!", // todo \(domain) - \(service)",
                type: .serviceCall,
                payload: nil //TODO: yeah i['m gonna need to store metadata huh serviceData
            )

            Current.clientEventStore.addEvent(event)
        }.then { _ in
            Guarantee.value(WebhookResponseHandlerResult.default)
        }.recover { _ in
            Guarantee.value(WebhookResponseHandlerResult.default)
        }
    }
}
