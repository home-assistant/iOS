import Foundation
import PromiseKit

public extension WebhookResponseIdentifier {
    static var unhandled: Self { .init(rawValue: "unhandled") }
}

struct WebhookResponseUnhandled: WebhookResponseHandler {
    init(api: HomeAssistantAPI) { }

    static func shouldReplace(request current: URLSessionTask, with proposed: URLSessionTask) -> Bool {
        // the unhandled variant never replaces requests. to customize, create another implementation.
        return false
    }

    func handle(result: Promise<Any>) -> Guarantee<WebhookResponseHandlerResult> {
        result.then { _ in
            Guarantee.value(WebhookResponseHandlerResult.default)
        }.recover { _ in
            Guarantee.value(WebhookResponseHandlerResult.default)
        }
    }
}
