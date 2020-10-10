import Foundation
import UserNotifications
import PromiseKit
import RealmSwift

extension WebhookResponseIdentifier {
    static var updateComplications: Self { .init(rawValue: "updateComplications") }
}

struct WebhookResponseUpdateComplications: WebhookResponseHandler {
    let api: HomeAssistantAPI
    init(api: HomeAssistantAPI) {
        self.api = api
    }

    static func shouldReplace(request current: WebhookRequest, with proposed: WebhookRequest) -> Bool {
        return true
    }

    static func request(for complications: Set<WatchComplication>) -> WebhookRequest? {
        Current.Log.verbose("complications \(complications.map { $0.Template.rawValue })")

        let templates = complications.reduce(into: [String: [String: String]]()) { payload, complication in
            let keyPrefix = "\(complication.Template.rawValue)|"

            payload.merge(
                complication.preRendered()
                    .mapKeys { keyPrefix + $0 }
                    .mapValues { ["template": $0] },
                uniquingKeysWith: { a, _ in a }
            )
        }

        if templates.isEmpty {
            return nil
        } else {
            return .init(type: "render_template", data: templates)
        }
    }

    func handle(
        request: Promise<WebhookRequest>,
        result: Promise<Any>
    ) -> Guarantee<WebhookResponseHandlerResult> {
        return firstly {
            result
        }.compactMap {
            return $0 as? [String: String]
        }.then { jsonDict -> Promise<Void> in
            Current.Log.verbose("JSON Dict1 \(jsonDict)")

            for (templateKey, renderedText) in jsonDict {
                let components = templateKey.components(separatedBy: "|")
                let rawTemplate = components[0]
                let key = components[1]
                let pred = NSPredicate(format: "rawTemplate == %@", rawTemplate)
                let realm = Realm.live()
                guard let complication = realm.objects(WatchComplication.self).filter(pred).first else {
                    Current.Log.error("Couldn't get complication from DB for \(rawTemplate)")
                    continue
                }

                Current.Log.info("updating value for complication \(rawTemplate) key \(key)")

                // swiftlint:disable:next force_try
                try! realm.write {
                    complication.updateRawRendered(for: key, value: renderedText)
                }

                Current.Log.verbose("complication \(complication.Data)")
            }

            if let syncError = HomeAssistantAPI.SyncWatchContext() {
                return .init(error: syncError)
            }

            return .value(())
        }.map { _ in
            WebhookResponseHandlerResult.default
        }.recover { error -> Guarantee<WebhookResponseHandlerResult> in
            Current.Log.error("got error: \(error)")
            return Guarantee.value(WebhookResponseHandlerResult.default)
        }
    }
}
