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

class GetCameraImageIntentHandler: NSObject, GetCameraImageIntentHandling {

    func confirm(intent: GetCameraImageIntent, completion: @escaping (GetCameraImageIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            print("Can't get a authenticated API", error)
            completion(GetCameraImageIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        if intent.cameraID != nil {
            // Camera ID already set
            completion(GetCameraImageIntentResponse(code: .ready, userActivity: nil))
        } else if let pasteboardString = UIPasteboard.general.string, pasteboardString.hasPrefix("camera.") {
            intent.cameraID = pasteboardString
            completion(GetCameraImageIntentResponse(code: .ready, userActivity: nil))
        } else {
            completion(GetCameraImageIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
        }
    }

    func handle(intent: GetCameraImageIntent, completion: @escaping (GetCameraImageIntentResponse) -> Void) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(GetCameraImageIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        if let cameraID = intent.cameraID {
            print("Getting camera frame for", cameraID)

            api.GetCameraImage(cameraEntityID: cameraID).done { frame in
                print("Successfully got camera image during shortcut")

                UIPasteboard.general.image = frame

                completion(GetCameraImageIntentResponse(code: .success, userActivity: nil))
            }.catch { error in
                print("Error when getting camera image in shortcut", error)
                let resp = GetCameraImageIntentResponse(code: .failure, userActivity: nil)
                resp.error = "Error during api.GetCameraImage: \(error.localizedDescription)"
                completion(resp)
            }

        } else {
            print("Unable to unwrap intent.cameraID")
            let resp = GetCameraImageIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap intent.cameraID"
            completion(resp)
        }
    }
}
