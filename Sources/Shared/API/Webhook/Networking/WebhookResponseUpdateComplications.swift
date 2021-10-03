import Foundation
import PromiseKit
import RealmSwift
import UserNotifications
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
        true
    }

    static func request(for complications: Set<WatchComplication>) -> WebhookRequest? {
        Current.Log.verbose("complications \(complications.map(\.identifier))")

        let templates = complications.reduce(into: [String: [String: String]]()) { payload, complication in
            let keyPrefix = "\(complication.identifier)|"

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
        firstly {
            result
        }.compactMap { result in
            result as? [String: Any]
        }.map { result in
            // turn the ["identifier|key": "value"] into ["identifier": ["key": "value"]]
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
            return realm.reentrantWrite {
                for (identifier, rendered) in paired {
                    if let complication = realm.object(ofType: watchComplicationClass, forPrimaryKey: identifier) {
                        Current.Log.verbose("updating \(identifier) with \(rendered)")
                        complication.updateRawRendered(from: rendered)
                    } else {
                        Current.Log.error("couldn't find complication for \(identifier)")
                    }
                }
            }
        }.done {
            #if os(watchOS)
            Self.updateComplications()
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

    #if os(watchOS)
    internal static func updateComplications() {
        let server = CLKComplicationServer.sharedInstance()

        server.activeComplications?.forEach {
            server.reloadTimeline(for: $0)
        }

        if #available(watchOS 7, *) {
            server.reloadComplicationDescriptors()
        }
    }
    #endif
}
