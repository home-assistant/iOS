import Foundation
import Intents
import PromiseKit
import UIKit

@available(iOS 13, watchOS 6, *)
class FireEventIntentHandler: NSObject, FireEventIntentHandling {
    typealias Intent = FireEventIntent

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

    func resolveEventName(for intent: Intent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let eventName = intent.eventName, eventName.isEmpty == false {
            Current.Log.info("using provided \(eventName)")
            completion(.success(with: eventName))
        } else {
            Current.Log.info("requesting a value")
            completion(.needsValue())
        }
    }

    func resolveEventData(for intent: Intent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let eventData = intent.eventData, eventData.isEmpty == false {
            Current.Log.info("using provided data \(eventData)")
            completion(.success(with: eventData))
        } else {
            Current.Log.info("using empty dictionary")
            completion(.notRequired())
        }
    }

    func handle(intent: Intent, completion: @escaping (FireEventIntentResponse) -> Void) {
        guard let server = Current.servers.server(for: intent) else {
            completion(.failure(error: "No server provided", eventName: intent.eventName!))
            return
        }

        Current.Log.verbose("Handling fire event shortcut \(intent)")

        var eventDataDict: [String: Any] = [:]

        if let storedData = intent.eventData, storedData.isEmpty == false, let data = storedData.data(using: .utf8) {
            do {
                if let jsonArray = try JSONSerialization.jsonObject(
                    with: data,
                    options: .allowFragments
                ) as? [String: Any] {
                    var isGenericPayload = true

                    if let eventName = jsonArray["eventName"] as? String {
                        intent.eventName = eventName
                        isGenericPayload = false
                    }

                    if let innerEventData = jsonArray["eventData"] as? [String: Any] {
                        eventDataDict = innerEventData
                        isGenericPayload = false
                    }

                    if isGenericPayload {
                        Current.Log.verbose("No known keys found, assuming generic payload")
                        eventDataDict = jsonArray
                    }
                } else {
                    Current.Log.error("Unable to parse event data to JSON during shortcut: \(storedData)")
                    let resp = FireEventIntentResponse(code: .failure, userActivity: nil)
                    resp.error = "Unable to parse event data to JSON during shortcut"
                    completion(resp)
                    return
                }
            } catch let error as NSError {
                Current.Log.error("Error when parsing event data to JSON during FireEvent: \(error)")
                let resp = FireEventIntentResponse(code: .failure, userActivity: nil)
                resp.error = "Service data not dictionary or JSON"
                completion(resp)
                return
            }
        }

        firstly {
            Current.api(for: server).CreateEvent(eventType: intent.eventName!, eventData: eventDataDict)
        }.done { _ in
            Current.Log.verbose("Successfully fired event during shortcut")
            let resp = FireEventIntentResponse(code: .success, userActivity: nil)
            resp.eventName = intent.eventName
            completion(resp)
        }.catch { error in
            Current.Log.error("Error when firing event in shortcut \(error)")
            let resp = FireEventIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Error when firing event in shortcut: \(error.localizedDescription)"
            completion(resp)
        }
    }
}
