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

class RenderTemplateIntentHandler: NSObject, RenderTemplateIntentHandling {

    func confirm(intent: RenderTemplateIntent, completion: @escaping (RenderTemplateIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            print("Can't get a authenticated API", error)
            completion(RenderTemplateIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        completion(RenderTemplateIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: RenderTemplateIntent, completion: @escaping (RenderTemplateIntentResponse) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(RenderTemplateIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        var successCode: RenderTemplateIntentResponseCode = .success

        if intent.template == nil, let pasteboardString = UIPasteboard.general.string {
            intent.template = pasteboardString
            successCode = .successViaClipboard
        } else {
            completion(.failure(error: "Template not previously set and no template found on clipboard"))
            return
        }

        if let templateStr = intent.template {
            print("Rendering template", templateStr)

            api.RenderTemplate(templateStr: templateStr).done { rendered in
                print("Successfully renderedTemplate")

                UIPasteboard.general.string = rendered

                completion(RenderTemplateIntentResponse(code: successCode, userActivity: nil))
            }.catch { error in
                print("Error when rendering template in shortcut", error)
                let resp = RenderTemplateIntentResponse(code: .failure, userActivity: nil)
                resp.error = "Error during api.RenderTemplate: \(error.localizedDescription)"
                completion(resp)
            }

        } else {
            print("Unable to unwrap intent.template")
            let resp = RenderTemplateIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap intent.template"
            completion(resp)
        }
    }
}
