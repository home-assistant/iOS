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
import PromiseKit
import Intents

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

        guard let cameraID = intent.cameraID else {
            Current.Log.error("Unable to unwrap intent.cameraID")
            let resp = GetCameraImageIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Unable to unwrap intent.cameraID"
            completion(resp)
            return
        }

        Current.Log.verbose("Getting camera frame for \(cameraID)")

        api.GetCameraImage(cameraEntityID: cameraID.identifier!).done { frame in
            Current.Log.verbose("Successfully got camera image during shortcut")

            guard let pngData = frame.pngData() else {
                Current.Log.error("Image data could not be converted to PNG")
                completion(.failure(error: "Image could not be converted to PNG"))
                return
            }

            // print("PNGData", pngData.base64EncodedString())

            let file = INFile(data: pngData, filename: "camera1", typeIdentifier: kUTTypePNG as String)

            print("Wrote file", file, file.fileURL, file.filename, file.typeIdentifier)

            let resp = GetCameraImageIntentResponse(code: .success, userActivity: nil)
            resp.image = file
            resp.cameraID = intent.cameraID
            print("Resp", resp)
            completion(resp)
        }.catch { error in
            Current.Log.error("Error when getting camera image in shortcut \(error)")
            let resp = GetCameraImageIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Error during api.GetCameraImage: \(error.localizedDescription)"
            completion(resp)
        }
    }

    func resolveCameraID(for intent: GetCameraImageIntent,
                         with completion: @escaping (EntityIDResolutionResult) -> Void) {
        guard let cameraID = intent.cameraID else { completion(EntityIDResolutionResult.needsValue()); return }
        completion(EntityIDResolutionResult.success(with: cameraID))
    }

    func provideCameraIDOptions(for intent: GetCameraImageIntent,
                                with completion: @escaping ([EntityID]?, Error?) -> Void) {
        firstly {
            HomeAssistantAPI.authenticatedAPIPromise
        }.then { api in
            api.GetStates()
        }.map { states -> [EntityID] in
            return states.filter { $0.Domain == "camera" }.map { EntityID(identifier: $0.ID, display: $0.ID) }
        }.done { cameras in
            completion(cameras, nil)
        }.catch { err in
            completion(nil, err)
        }
    }
}
