import Foundation
import UserNotifications
import PromiseKit
import RealmSwift
#if os(watchOS)
import ClockKit
#endif

extension WebhookResponseIdentifier {
    static var updateComplications: Self { .init(rawValue: "updateComplications") }
}

struct WebhookResponseUpdateComplications: WebhookResponseHandler {
    let api: HomeAssistantAPI

    // for tests, since Realm can't query subclasses in a query
    var watchComplicationClass: WatchComplication.Type = WatchComplication.self

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
                complication.rawRendered()
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
        }.compactMap { result in
            result as? [String: Any]
        }.map { result in
            // turn the ["template|key": "value"] into ["template": ["key": "value"]]
            result.reduce(into: [String: [String: Any]]()) { accumulator, value in
                let components = value.key.components(separatedBy: "|")
                guard components.count >= 2 else {
                    Current.Log.error("couldn't figure out naming for \(value.key)")
                    return
                }
                accumulator[components[0], default: [:]][components[1]] = value.value
            }
        }.then { paired -> Promise<Void> in
            let realm = Current.realm()
            let base = realm.objects(watchComplicationClass)

            try realm.write {
                for (template, rendered) in paired {
                    if let complication = base.filter("rawTemplate == %@", template).first {
                        Current.Log.verbose("updating \(template) with \(rendered)")
                        complication.updateRawRendered(from: rendered)
                    } else {
                        Current.Log.error("couldn't find complication for \(template)")
                    }
                }
            }

            return .value(())
        }.done {
            #if os(watchOS)
            let server = CLKComplicationServer.sharedInstance()

            server.activeComplications?.forEach {
                server.reloadTimeline(for: $0)
            }
            #else
            _ = HomeAssistantAPI.SyncWatchContext()
            #endif
        }.map { _ in
            WebhookResponseHandlerResult.default
        }.recover { error -> Guarantee<WebhookResponseHandlerResult> in
            Current.Log.error("got error: \(error)")
            return Guarantee.value(WebhookResponseHandlerResult.default)
        }
    }
}
