import Foundation
import PromiseKit

public extension WebhookResponseIdentifier {
    static var unhandled: Self { .init(rawValue: "unhandled") }
}

struct WebhookResponseUnhandled: WebhookResponseHandler {
    init(api: HomeAssistantAPI) {}

    static func shouldReplace(request current: WebhookRequest, with proposed: WebhookRequest) -> Bool {
        // the unhandled variant never replaces requests. to customize, create another implementation.
        false
    }

    func handle(
        request: Promise<WebhookRequest>,
        result: Promise<Any>
    ) -> Guarantee<WebhookResponseHandlerResult> {
        result.then { _ in
            Guarantee.value(WebhookResponseHandlerResult.default)
        }.recover { _ in
            Guarantee.value(WebhookResponseHandlerResult.default)
        }
    }
}
