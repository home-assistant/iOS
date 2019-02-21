//
//  GetCameraImage.swift
//  SiriIntents
//
//  Created by Robert Trencheny on 2/19/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Shared
import CleanroomLogger

class GetCameraImageIntentHandler: NSObject, GetCameraImageIntentHandling {

    func confirm(intent: GetCameraImageIntent, completion: @escaping (GetCameraImageIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            Log.error?.message("Can't get a authenticated API \(error)")
            completion(GetCameraImageIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        completion(GetCameraImageIntentResponse(code: .ready, userActivity: nil))
    }

    func handle(intent: GetCameraImageIntent, completion: @escaping (GetCameraImageIntentResponse) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(GetCameraImageIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        var successCode: GetCameraImageIntentResponseCode = .success

        if intent.cameraID == nil, let pasteboardString = UIPasteboard.general.string,
            pasteboardString.hasPrefix("camera.") {
            intent.cameraID = pasteboardString
            successCode = .successViaClipboard
        } else {
            completion(GetCameraImageIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
            return
        }

        if let cameraID = intent.cameraID {
            Log.verbose?.message("Getting camera frame for \(cameraID)")

            api.GetCameraImage(cameraEntityID: cameraID).done { frame in
                Log.verbose?.message("Successfully got camera image during shortcut")

                UIPasteboard.general.image = frame

                completion(GetCameraImageIntentResponse(code: successCode, userActivity: nil))
            }.catch { error in
                Log.error?.message("Error when getting camera image in shortcut \(error)")
                let resp = GetCameraImageIntentResponse(code: .failure, userActivity: nil)
                resp.error = "Error during api.GetCameraImage: \(error.localizedDescription)"
                completion(resp)
            }

        } else {
            Log.error?.message("Unable to unwrap intent.cameraID")
            let resp = GetCameraImageIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap intent.cameraID"
            completion(resp)
        }
    }
}
