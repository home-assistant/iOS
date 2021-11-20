import Foundation
import HAKit
import Intents
import PromiseKit
import Shared
import UIKit

class CallServiceIntentHandler: NSObject, CallServiceIntentHandling {
    func resolveService(for intent: CallServiceIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let serviceName = intent.service, serviceName.isEmpty == false {
            Current.Log.info("using given \(serviceName)")
            completion(.success(with: serviceName))
        } else {
            Current.Log.info("loading values due to no service")
            completion(.needsValue())
        }
    }

    func resolvePayload(for intent: CallServiceIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let servicePayload = intent.payload, servicePayload.isEmpty == false {
            Current.Log.info("using provided \(servicePayload)")
            completion(.success(with: servicePayload))
        } else {
            Current.Log.info("using default empty dictionary value")
            completion(.success(with: "{}"))
        }
    }

    func resolveServer(
        for intent: CallServiceIntent,
        with completion: @escaping (IntentServerResolutionResult) -> Void
    ) {
        if let server = server(for: intent) {
            completion(.success(with: .init(server: server)))
        } else {
            completion(.needsValue())
        }
    }

    func provideServiceOptions(for intent: CallServiceIntent, with completion: @escaping ([String]?, Error?) -> Void) {
        guard let server = server(for: intent) else {
            completion(nil, nil)
            return
        }

        firstly {
            Current.api(for: server).connection.send(.getServices()).promise
        }
        .map(\.all)
        .mapValues(\.domainServicePair)
        .done { completion($0, nil) }
        .catch { completion(nil, $0) }
    }

    @available(iOS 14, *)
    func provideServiceOptionsCollection(
        for intent: CallServiceIntent,
        with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void
    ) {
        provideServiceOptions(for: intent) { services, error in
            completion(services.flatMap { .init(items: $0.map { $0 as NSString }) }, error)
        }
    }

    func provideServerOptions(
        for intent: CallServiceIntent,
        with completion: @escaping ([IntentServer]?, Error?) -> Void
    ) {
        completion(Current.servers.all.map { IntentServer(server: $0) }, nil)
    }

    @available(iOS 14, *)
    func provideServerOptionsCollection(
        for intent: CallServiceIntent,
        with completion: @escaping (INObjectCollection<IntentServer>?, Error?) -> Void
    ) {
        provideServerOptions(for: intent) { servers, error in
            completion(servers.flatMap { .init(items: $0) }, error)
        }
    }

    func handle(intent: CallServiceIntent, completion: @escaping (CallServiceIntentResponse) -> Void) {
        var payloadDict: [String: Any] = [:]

        if let payload = intent.payload, payload.isEmpty == false {
            let data = payload.data(using: .utf8)!
            do {
                if let jsonArray = try JSONSerialization.jsonObject(
                    with: data,
                    options: .allowFragments
                ) as? [String: Any] {
                    payloadDict = jsonArray
                } else {
                    Current.Log.error("Unable to parse stored payload: \(payload)")
                    completion(.failure(error: "Unable to parse stored payload"))
                    return
                }
            } catch let error as NSError {
                Current.Log.error("Error when parsing stored payload to JSON during CallService \(error)")
                let errStr = "Error when parsing stored payload to JSON during CallService: \(error)"
                completion(.failure(error: errStr))
                return
            }
        }

        Current.Log.verbose("Configured intent \(intent)")

        guard let serviceName = intent.service else {
            completion(.failure(error: "No service name provided"))
            return
        }

        guard let server = server(for: intent) else {
            completion(.failure(error: "No server provided"))
            return
        }

        let splitServiceNameInput = serviceName.split(separator: ".")

        guard splitServiceNameInput.count == 2 else {
            Current.Log.warning("Invalid service \(serviceName), count is \(splitServiceNameInput.count)")
            let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Invalid service name"
            completion(resp)
            return
        }

        let domain = String(splitServiceNameInput[0])
        let service = String(splitServiceNameInput[1])

        Current.Log.verbose("Handling call service shortcut \(domain), \(service)")

        firstly {
            Current.api(for: server).CallService(
                domain: domain,
                service: service,
                serviceData: payloadDict,
                shouldLog: true
            )
        }.done { _ in
            Current.Log.verbose("Successfully called service during shortcut")
            let resp = CallServiceIntentResponse(code: .success, userActivity: nil)
            resp.domain = domain
            resp.service = service
            completion(resp)
        }.catch { error in
            Current.Log.error("Error when calling service in shortcut \(error)")
            let resp = CallServiceIntentResponse(code: .failure, userActivity: nil)
            resp.error = "Error during api.callService: \(error.localizedDescription)"
            completion(resp)
        }
    }

    private func server(for intent: CallServiceIntent) -> Server? {
        if let server = intent.server?.identifier.flatMap({ Current.servers.server(for: .init(rawValue: $0)) }) {
            return server
        } else if let server = Current.servers.all.first, Current.servers.all.count == 1 {
            return server
        } else {
            return nil
        }
    }
}
