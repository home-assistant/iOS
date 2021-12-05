import Foundation
import Intents
import PromiseKit
import UIKit

@available(iOS 13, watchOS 6, *)
class RenderTemplateIntentHandler: NSObject, RenderTemplateIntentHandling {
    typealias Intent = RenderTemplateIntent

    func resolveServer(for intent: Intent, with completion: @escaping (IntentServerResolutionResult) -> Void) {
        if let server = Current.servers.server(for: intent) {
            completion(.success(with: .init(server: server)))
        } else {
            completion(.needsValue())
        }
    }

    func provideServerOptions(for intent: Intent, with completion: @escaping ([IntentServer]?, Error?) -> Void) {
        completion(IntentServer.all, nil)
    }

    @available(iOS 14, watchOS 7, *)
    func provideServerOptionsCollection(
        for intent: Intent,
        with completion: @escaping (INObjectCollection<IntentServer>?, Error?) -> Void
    ) {
        completion(.init(items: IntentServer.all), nil)
    }

    func resolveTemplate(
        for intent: Intent,
        with completion: @escaping (INStringResolutionResult) -> Void
    ) {
        if let templateStr = intent.template, templateStr.isEmpty == false {
            Current.Log.info("using provided '\(templateStr)'")
            completion(.success(with: templateStr))
        } else {
            Current.Log.info("requesting a value")
            completion(.needsValue())
        }
    }

    func handle(intent: Intent, completion: @escaping (RenderTemplateIntentResponse) -> Void) {
        guard let templateStr = intent.template else {
            Current.Log.error("Unable to unwrap intent.template")
            let resp = RenderTemplateIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap intent.template"
            completion(resp)
            return
        }

        guard let server = Current.servers.server(for: intent) else {
            completion(.failure(error: "no server selected"))
            return
        }

        Current.Log.verbose("Rendering template \(templateStr)")

        Current.api(for: server).connection.subscribe(
            to: .renderTemplate(templateStr),
            initiated: { result in
                if case let .failure(error) = result {
                    Current.Log.error("Error when rendering template in intent \(error)")
                    let resp = RenderTemplateIntentResponse(code: .failure, userActivity: nil)
                    completion(resp)
                }
            }, handler: { token, data in
                token.cancel()
                Current.Log.verbose("Successfully renderedTemplate")

                let resp = RenderTemplateIntentResponse(code: .success, userActivity: nil)
                resp.renderedTemplate = String(describing: data.result)

                completion(resp)
            }
        )
    }
}
