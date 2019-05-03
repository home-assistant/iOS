//
//  GetCameraImage.swift
//  SiriIntents
//
//  Created by Robert Trencheny on 2/19/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import MobileCoreServices
import UIKit
import Shared

class GetCameraImageIntentHandler: NSObject, GetCameraImageIntentHandling {

    func confirm(intent: GetCameraImageIntent, completion: @escaping (GetCameraImageIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            Current.Log.error("Can't get a authenticated API \(error)")
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
            successCode = .successViaPasteboard
        } else {
            completion(GetCameraImageIntentResponse(code: .failurePasteboardNotParseable, userActivity: nil))
            return
        }

        if let cameraID = intent.cameraID {
            Current.Log.verbose("Getting camera frame for \(cameraID)")

            api.GetCameraImage(cameraEntityID: cameraID).done { frame in
                Current.Log.verbose("Successfully got camera image during shortcut")

                guard let pngData = frame.pngData() else {
                    Current.Log.error("Image data could not be converted to PNG")
                    completion(.failure(error: "Image could not be converted to PNG"))
                    return
                }

                UIPasteboard.general.setData(pngData, forPasteboardType: kUTTypePNG as String)

                completion(GetCameraImageIntentResponse(code: successCode, userActivity: nil))
            }.catch { error in
                Current.Log.error("Error when getting camera image in shortcut \(error)")
                let resp = GetCameraImageIntentResponse(code: .failure, userActivity: nil)
                resp.error = "Error during api.GetCameraImage: \(error.localizedDescription)"
                completion(resp)
            }

        } else {
            Current.Log.error("Unable to unwrap intent.cameraID")
            let resp = GetCameraImageIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap intent.cameraID"
            completion(resp)
        }
    }
}
