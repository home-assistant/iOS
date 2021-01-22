//
//  RenderTemplate.swift
//  SiriIntents
//
//  Created by Robert Trencheny on 2/19/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Shared
import Intents
import PromiseKit

class RenderTemplateIntentHandler: NSObject, RenderTemplateIntentHandling {
    func resolveTemplate(for intent: RenderTemplateIntent,
                         with completion: @escaping (INStringResolutionResult) -> Void) {
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

        Current.api.then { api in
            api.RenderTemplate(templateStr: templateStr)
        }.done { rendered in
            Current.Log.verbose("Successfully renderedTemplate")

            let resp = RenderTemplateIntentResponse(code: .success, userActivity: nil)
            resp.renderedTemplate = String(describing: rendered)

            completion(resp)
        }.catch { error in
            Current.Log.error("Error when rendering template in shortcut \(error)")
            let resp = RenderTemplateIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Error during api.RenderTemplate: \(error.localizedDescription)"
            completion(resp)
        }
    }
}
