import Foundation
import PromiseKit
import UserNotifications
import ObjectMapper

public class WebhookManager: NSObject {
    public static let URLSessionIdentifier = "hass.webhook_manager"

    private var backingBackgroundUrlSession: URLSession!
    private var backgroundUrlSession: URLSession { return backingBackgroundUrlSession }
    private let ephemeralUrlSession: URLSession
    private let backgroundEventGroup: DispatchGroup = DispatchGroup()
    private var pendingData: [Int: Data] = [:]
    private var resolverForIdentifier: [Int: Resolver<Void>] = [:]
    private var responseHandlers = [WebhookResponseIdentifier: WebhookResponseHandler.Type]()

    internal enum WebhookManagerError: Error {
        case noApi
        case unregisteredIdentifier
        case unexpectedType(given: String, desire: String)
        case unmappableValue
    }

    // MARK: - Lifecycle

    override internal init() {
        let configuration = with(URLSessionConfiguration.background(withIdentifier: Self.URLSessionIdentifier)) {
            $0.sharedContainerIdentifier = Constants.AppGroupID
        }

        let queue = with(OperationQueue()) {
            $0.maxConcurrentOperationCount = 1
        }

        self.ephemeralUrlSession = URLSession(configuration: .ephemeral)

        super.init()

        self.backingBackgroundUrlSession = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: queue
        )

        register(responseHandler: WebhookResponseUnhandled.self, for: .unhandled)
    }

    internal func register(
        responseHandler: WebhookResponseHandler.Type,
        for identifier: WebhookResponseIdentifier
    ) {
        precondition(responseHandlers[identifier] == nil)
        responseHandlers[identifier] = responseHandler
    }

    public func handleBackground(for identifier: String, completionHandler: @escaping () -> Void) {
        Current.Log.notify("handleBackground started")
        // the pair of this enter is in urlSessionDidFinishEvents
        backgroundEventGroup.enter()

        backgroundEventGroup.notify(queue: DispatchQueue.main) {
            Current.Log.notify("final completion")
            completionHandler()
        }
    }

    // MARK: - Sending Ephemeral

    public func sendEphemeral(request: WebhookRequest) -> Promise<Void> {
        let promise: Promise<Any> = sendEphemeral(request: request)
        return promise.asVoid()
    }

    public func sendEphemeral<MappableResult: BaseMappable>(request: WebhookRequest) -> Promise<MappableResult> {
        let promise: Promise<Any> = sendEphemeral(request: request)
        return promise.map {
            if let result = Mapper<MappableResult>().map(JSONObject: $0) {
                return result
            } else {
                throw WebhookManagerError.unmappableValue
            }
        }
    }

    public func sendEphemeral<MappableResult: BaseMappable>(request: WebhookRequest) -> Promise<[MappableResult]> {
        let promise: Promise<Any> = sendEphemeral(request: request)
        return promise.map {
            if let result = Mapper<MappableResult>(shouldIncludeNilValues: false).mapArray(JSONObject: $0) {
                return result
            } else {
                throw WebhookManagerError.unmappableValue
            }
        }
    }

    public func sendEphemeral<ResponseType>(request: WebhookRequest) -> Promise<ResponseType> {
        attemptNetworking { [ephemeralUrlSession] in
            firstly {
                Self.urlRequest(for: request)
            }.then { urlRequest, data in
                ephemeralUrlSession.uploadTask(.promise, with: urlRequest, from: data)
            }
        }.then { data, response in
            Promise.value(data).webhookJson(
                on: DispatchQueue.global(qos: .utility),
                statusCode: (response as? HTTPURLResponse)?.statusCode
            )
        }.map { possible in
            if let value = possible as? ResponseType {
                return value
            } else {
                throw WebhookManagerError.unexpectedType(
                    given: String(describing: type(of: possible)),
                    desire: String(describing: ResponseType.self)
                )
            }
        }.tap { result in
            switch result {
            case .fulfilled(let response):
                Current.Log.info {
                    var log = "got successful response for \(request.PayloadType ?? "(unknown)")"
                    if Current.isDebug {
                        log += ": \(response)"
                    }
                    return log
                }
            case .rejected(let error):
                Current.Log.error("got failure for \(request.PayloadType ?? "(unknown)"): \(error)")
            }
        }
    }

    // MARK: - Sending Persistent

    public func send(
        identifier: WebhookResponseIdentifier = .unhandled,
        request: WebhookRequest
    ) -> Promise<Void> {
        guard let handlerType = responseHandlers[identifier] else {
            Current.Log.error("no existing handler for \(identifier), not sending request")
            return .init(error: WebhookManagerError.unregisteredIdentifier)
        }

        let (promise, seal) = Promise<Void>.pending()

        firstly {
            Self.urlRequest(for: request, identifier: identifier)
        }.done { [backgroundUrlSession] urlRequest, data in
            let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let temporaryFile = temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("json")
            try data.write(to: temporaryFile, options: [])
            let task = backgroundUrlSession.uploadTask(with: urlRequest, fromFile: temporaryFile)

            self.evaluateCancellable(by: task, with: promise)
            self.resolverForIdentifier[task.taskIdentifier] = seal
            task.resume()

            try FileManager.default.removeItem(at: temporaryFile)
        }.catch { [weak self] error in
            self?.invoke(handler: handlerType, result: .init(error: error), resolver: seal)
        }

        return promise
    }

    // MARK: - Private

    private func evaluateCancellable(by newTask: URLSessionTask, with newPromise: Promise<Void>) {
        guard let newType = responseHandler(from: newTask) else {
            Current.Log.error("couldn't determine request type from \(newTask)")
            return
        }

        backgroundUrlSession.getAllTasks { tasks in
            tasks.filter { thisTask in
                if let thisType = self.responseHandler(from: thisTask), thisType == newType, thisTask != newTask {
                    return newType.shouldReplace(request: thisTask, with: newTask)
                } else {
                    return false
                }
            }.forEach { existingTask in
                if let existingResolver = self.resolverForIdentifier[existingTask.taskIdentifier] {
                    newPromise.pipe { existingResolver.resolve($0) }
                }
                existingTask.cancel()
            }
        }
    }

    private static func urlRequest(
        for request: WebhookRequest,
        identifier: WebhookResponseIdentifier? = nil
    ) -> Promise<(URLRequest, Data)> {
        firstly {
            HomeAssistantAPI.authenticatedAPIPromise
        }.map { api in
            var urlRequest = try URLRequest(
                url: api.connectionInfo.webhookURL,
                method: .post
            )
            identifier?.augment(request: &urlRequest)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return (urlRequest, try JSONSerialization.data(withJSONObject: request.toJSON(), options: []))
        }
    }

    private func handle(result: WebhookResponseHandlerResult) {
        if let notification = result.notification {
            UNUserNotificationCenter.current().add(notification) { error in
                if let error = error {
                    Current.Log.error("failed to add notification for result \(result): \(error)")
                }
            }
        }
    }

    private func responseHandler(from task: URLSessionTask) -> WebhookResponseHandler.Type? {
        guard let request = task.originalRequest, let identifier = WebhookResponseIdentifier(request: request) else {
            Current.Log.error("unknown response type for \(task)")
            return nil
        }

        guard let handlerType = responseHandlers[identifier] else {
            Current.Log.error("unknown response identifier \(identifier) for \(task)")
            return nil
        }

        return handlerType
    }
}

extension WebhookManager: URLSessionDelegate {
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Current.Log.notify("event delivery ended")
        backgroundEventGroup.leave()
    }
}

extension WebhookManager: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        pendingData[dataTask.taskIdentifier, default: Data()].append(data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let data = pendingData[task.taskIdentifier]
        pendingData.removeValue(forKey: task.taskIdentifier)

        guard error?.isCancelled != true else {
            Current.Log.info("ignoring cancelled task")
            return
        }

        let result = Promise<Data?> { seal in
            if let error = error {
                seal.reject(error)
            } else {
                seal.fulfill(data)
            }
        }.webhookJson(
            on: DispatchQueue.global(qos: .utility),
            statusCode: (task.response as? HTTPURLResponse)?.statusCode
        )

        // dispatch
        if let handlerType = responseHandler(from: task) {
            // logging
            result.done { body in
                if Current.isDebug {
                    Current.Log.info("got response for \(handlerType) \(body)")
                }
            }.catch { error in
                Current.Log.error("failed request for \(handlerType): \(error)")
            }

            invoke(
                handler: handlerType,
                result: result,
                resolver: resolverForIdentifier[task.taskIdentifier]
            )
        } else {
            Current.Log.notify("no handler for background task")
            Current.Log.error("couldn't find appropriate handler for \(task)")
        }
    }

    private func invoke(
        handler handlerType: WebhookResponseHandler.Type,
        result: Promise<Any>,
        resolver: Resolver<Void>?
    ) {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            Current.Log.error("no api")
            return
        }

        Current.Log.notify("starting \(handlerType)")
        backgroundEventGroup.enter()

        let handler = handlerType.init(api: api)
        let handlerPromise = firstly {
            handler.handle(result: result)
        }.done { [weak self] result in
            // keep the handler around until it finishes
            withExtendedLifetime(handler) {
                self?.handle(result: result)
            }
        }

        firstly {
            when(fulfilled: [handlerPromise.asVoid(), result.asVoid()])
        }.tap {
            resolver?.resolve($0)
        }.ensure { [backgroundEventGroup] in
            Current.Log.notify("finished \(handlerType)")
            backgroundEventGroup.leave()
        }.cauterize()
    }
}
