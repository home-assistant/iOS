import Foundation
import Intents
import MobileCoreServices
import PromiseKit
import UIKit

class GetCameraImageIntentHandler: NSObject, GetCameraImageIntentHandling {
    typealias Intent = GetCameraImageIntent

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

    func provideServerOptionsCollection(
        for intent: Intent,
        with completion: @escaping (INObjectCollection<IntentServer>?, Error?) -> Void
    ) {
        completion(.init(items: IntentServer.all), nil)
    }

    func resolveCameraID(
        for intent: Intent,
        with completion: @escaping (INStringResolutionResult) -> Void
    ) {
        if let cameraID = intent.cameraID, cameraID.hasPrefix("camera.") {
            Current.Log.info("using given \(cameraID)")
            completion(.success(with: cameraID))
        } else {
            Current.Log.info("loading values due to no camera id")
            completion(.needsValue())
        }
    }

    func provideCameraIDOptions(
        for intent: Intent,
        with completion: @escaping ([String]?, Error?) -> Void
    ) {
        guard let server = Current.servers.server(for: intent),
              let connection = Current.api(for: server)?.connection else {
            completion(nil, PickAServerError.error)
            return
        }

        connection.caches.states().once().promise.map(\.all)
            .filterValues { $0.domain == "camera" }
            .mapValues(\.entityId)
            .sortedValues()
            .done { completion($0, nil) }
            .catch { completion(nil, $0) }
    }

    func provideCameraIDOptionsCollection(
        for intent: Intent,
        with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void
    ) {
        provideCameraIDOptions(for: intent) { identifiers, error in
            completion(identifiers.flatMap { .init(items: $0.map { $0 as NSString }) }, error)
        }
    }

    func handle(intent: Intent, completion: @escaping (GetCameraImageIntentResponse) -> Void) {
        guard let server = Current.servers.server(for: intent), let api = Current.api(for: server) else {
            completion(
                .failure(
                    error: "No server provided, active URL: \(String(describing: Current.servers.server(for: intent)?.info.connection.activeURL()?.absoluteString))"
                )
            )
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

                let resp = GetCameraImageIntentResponse(code: .success, userActivity: nil)
                resp.cameraImage = INFile(
                    data: pngData,
                    filename: "\(cameraID)_still.png",
                    typeIdentifier: kUTTypePNG as String
                )
                resp.cameraID = cameraID
                completion(resp)
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
