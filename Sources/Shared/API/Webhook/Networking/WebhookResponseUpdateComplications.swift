import Foundation
import GRDB
import PromiseKit
import UserNotifications

extension WebhookResponseIdentifier {
    static var updateComplications: Self { .init(rawValue: "updateComplications") }
}

struct WebhookResponseUpdateComplications: WebhookResponseHandler {
    let api: HomeAssistantAPI

    init(api: HomeAssistantAPI) {
        self.api = api
    }

    static func shouldReplace(request current: WebhookRequest, with proposed: WebhookRequest) -> Bool {
        true
    }

    static func request(for complications: some Sequence<WatchComplication>) -> WebhookRequest? {
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
            Promise { seal in
                do {
                    try Current.database().write { db in
                        for (identifier, rendered) in paired {
                            if var complication = try WatchComplication.fetchOne(db, key: identifier) {
                                Current.Log.verbose("updating \(identifier) with \(rendered)")
                                complication.updateRawRendered(from: rendered)
                                try complication.update(db)
                            } else {
                                Current.Log.error("couldn't find complication for \(identifier)")
                            }
                        }
                    }
                    seal.fulfill(())
                } catch {
                    seal.reject(error)
                }
            }
        }.done {
            #if os(watchOS)
            // The face renders from the WidgetKit snapshots in the app group, not from these rows, so
            // announce the write and let the watch app rebuild them (see
            // `ExtensionDelegate.observeLegacyComplicationRenders`). Reloading ClockKit here — which is
            // what this used to do — updates nothing: the watch left ClockKit behind in #5036.
            NotificationCenter.default.post(name: WatchComplication.didChangeNotification, object: nil)
            #else
            HomeAssistantAPI.syncWatchContext()
            // Current watch builds only read complications from the database mirror (the context
            // keys are legacy), so freshly rendered templates must also go out via a mirror push.
            WatchMirrorPushCoordinator.schedule(reason: .complicationChanged)
            #endif
        }.map { _ in
            WebhookResponseHandlerResult.default
        }.recover { error -> Guarantee<WebhookResponseHandlerResult> in
            Current.Log.error("got error: \(error)")
            return Guarantee.value(WebhookResponseHandlerResult.default)
        }
    }
}
