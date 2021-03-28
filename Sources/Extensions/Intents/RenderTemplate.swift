import Foundation
import Intents
import PromiseKit
import Shared
import UIKit

class RenderTemplateIntentHandler: NSObject, RenderTemplateIntentHandling {
    func resolveTemplate(
        for intent: RenderTemplateIntent,
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

    func handle(intent: RenderTemplateIntent, completion: @escaping (RenderTemplateIntentResponse) -> Void) {
        guard let templateStr = intent.template else {
            Current.Log.error("Unable to unwrap intent.template")
            let resp = RenderTemplateIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap intent.template"
            completion(resp)
            return
        }

        Current.Log.verbose("Rendering template \(templateStr)")

        Current.apiConnection.subscribe(
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
