#if !os(watchOS)
import Foundation
import HAKit
import HAKit_PromiseKit
import PromiseKit

/// WebSocket implementations of `AppIntentServerAPI` — see that type for why watchOS takes the REST
/// path instead.
extension AppIntentServerAPI {
    static func callActionViaWebSocket(
        server: Server,
        domain: String,
        service: String,
        data: [String: Any],
        returnResponse: Bool
    ) async throws -> CallServiceResponse {
        try await haConnection(for: server)
            .send(.callService(
                domain: domain,
                service: service,
                serviceData: data,
                returnResponse: returnResponse
            ))
            .promise
            .asyncValue()
    }

    static func renderTemplateViaWebSocket(server: Server, template: String) async throws -> String {
        let connection = try haConnection(for: server)
        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var settled = false
            // `initiated` and `handler` can both fire; the continuation may only resume once.
            func settleOnce(_ body: () -> Void) {
                lock.lock()
                let shouldRun = !settled
                settled = true
                lock.unlock()
                if shouldRun { body() }
            }

            connection.subscribe(to: .renderTemplate(template), initiated: { result in
                if case let .failure(error) = result {
                    settleOnce { continuation.resume(throwing: error) }
                }
            }, handler: { token, data in
                token.cancel()
                settleOnce { continuation.resume(returning: String(describing: data.result)) }
            })
        }
    }

    static func actionDefinitionsViaWebSocket(server: Server) async throws -> [IntentActionDefinition] {
        let connection = try haConnection(for: server)
        return try await when(
            fulfilled:
            connection.send(HARequest(type: .getServices)).promise,
            serviceIcons(on: connection),
            serviceTranslations(on: connection)
        )
        .map { data, icons, translations in
            guard case let .dictionary(rawDictionary) = data,
                  let dictionary = rawDictionary as? [String: [String: [String: Any]]] else {
                return []
            }

            return dictionary.flatMap { domain, services in
                services.map { service, metadata in
                    IntentActionDefinition(
                        domain: domain,
                        service: service,
                        name: metadata["name"] as? String,
                        actionDescription: metadata["description"] as? String,
                        descriptionPlaceholders: stringDictionary(from: metadata["description_placeholders"]),
                        translationKey: metadata["translation_key"] as? String,
                        icon: icons[domain]?[service] ?? metadata["icon"] as? String,
                        supportsResponse: metadata["response"] is [String: Any],
                        translations: translations
                    )
                }
            }
            .sorted { first, second in
                first.actionId.localizedCaseInsensitiveCompare(second.actionId) == .orderedAscending
            }
        }
        .asyncValue(timeout: requestTimeout)
    }

    static func entitiesViaWebSocket(server: Server, domain: Domain) async throws -> [HAEntity] {
        try await haConnection(for: server)
            .caches
            .states()
            .once()
            .promise
            .map(\.all)
            .filterValues { $0.domain == domain.rawValue }
            .map { entities in sortedByDisplayName(entities) }
            .asyncValue(timeout: requestTimeout)
    }

    static func entityStateViaWebSocket(server: Server, entityId: String) async throws -> HAEntity {
        // REST over the socket, not the states cache: the cache is a subscription for one read.
        let data = try await haConnection(for: server)
            .send(HARequest(type: .rest(.get, "states/\(entityId)"), shouldRetry: true))
            .promise
            .asyncValue(timeout: requestTimeout)
        return try HAEntity(data: data)
    }

    static func assistViaWebSocket(server: Server, prompt: String, pipelineId: String?) async throws -> String {
        try await AssistPromptRunner(server: server).assist(prompt: prompt, pipelineId: pipelineId)
    }

    private static func haConnection(for server: Server) throws -> HAConnection {
        guard let connection = Current.api(for: server)?.connection else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }
        return connection
    }

    private static func serviceIcons(on connection: HAConnection) -> Promise<[String: [String: String]]> {
        connection.send(HARequest(type: .webSocket("frontend/get_icons"), data: [
            "category": "services",
        ]))
        .promise
        .map { data in
            guard case let .dictionary(rawDictionary) = data,
                  let resources = rawDictionary["resources"] as? [String: [String: [String: Any]]] else {
                return [:]
            }

            return resources.reduce(into: [String: [String: String]]()) { result, domain in
                result[domain.key] = domain.value.reduce(into: [String: String]()) { services, service in
                    services[service.key] = service.value["service"] as? String
                }
            }
        }
        .recover { _ -> Promise<[String: [String: String]]> in .value([:]) }
    }

    private static func serviceTranslations(on connection: HAConnection) -> Promise<[String: String]> {
        frontendTranslationLanguage(on: connection)
            .then { language -> Promise<[String: String]> in
                serviceTranslations(on: connection, language: language)
            }
            .recover { _ -> Promise<[String: String]> in .value([:]) }
    }

    private static func frontendTranslationLanguage(on connection: HAConnection) -> Promise<String> {
        connection.send(HARequest(type: .webSocket("frontend/get_user_data"), data: [
            "key": "language",
        ]))
        .promise
        .map { data in
            guard case let .dictionary(rawDictionary) = data,
                  let value = rawDictionary["value"] as? [String: Any],
                  let language = value["language"] as? String,
                  language.isEmpty == false else {
                return Locale.homeAssistantTranslationIdentifier
            }

            return language
        }
        .recover { _ -> Promise<String> in .value(Locale.homeAssistantTranslationIdentifier) }
    }

    private static func serviceTranslations(
        on connection: HAConnection,
        language: String
    ) -> Promise<[String: String]> {
        connection.send(HARequest(type: .webSocket("frontend/get_translations"), data: [
            "language": language,
            "category": "services",
        ]))
        .promise
        .map { data in
            guard case let .dictionary(rawDictionary) = data,
                  let resources = rawDictionary["resources"] as? [String: Any] else {
                return [:]
            }

            return stringDictionary(from: resources)
        }
    }

    private static func stringDictionary(from value: Any?) -> [String: String] {
        guard let dictionary = value as? [String: Any] else {
            return [:]
        }

        return dictionary.reduce(into: [String: String]()) { result, item in
            if let string = item.value as? String {
                result[item.key] = string
            } else {
                result[item.key] = String(describing: item.value)
            }
        }
    }

    /// Runs one Assist pipeline to completion over the WebSocket and resolves with the spoken answer.
    private final class AssistPromptRunner: NSObject, AssistServiceDelegate {
        private let server: Server
        private var assistService: AssistService?
        private var continuation: CheckedContinuation<String, Error>?

        init(server: Server) {
            self.server = server
            super.init()
        }

        func assist(prompt: String, pipelineId: String?) async throws -> String {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let assistService = AssistService(server: server)
                assistService.delegate = self
                self.assistService = assistService
                assistService.assist(source: .text(input: prompt, pipelineId: pipelineId, expectTTS: false))
            }
        }

        func didReceiveStreamResponseChunk(_ content: String) {
            /* no-op */
        }

        func didReceiveEvent(_ event: AssistEvent) {
            /* no-op */
        }

        func didReceiveSttContent(_ content: String) {
            /* no-op */
        }

        func didReceiveIntentEndContent(_ content: String) {
            resume(with: .success(content))
        }

        func didReceiveGreenLightForAudioInput() {
            /* no-op */
        }

        func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
            /* no-op */
        }

        func didReceiveError(code: String, message: String) {
            resume(with: .failure(ShortcutAppIntentError("\(code) - \(message)")))
        }

        private func resume(with result: Swift.Result<String, Error>) {
            guard let continuation else { return }
            self.continuation = nil
            assistService = nil

            switch result {
            case let .success(value):
                continuation.resume(returning: value)
            case let .failure(error):
                continuation.resume(throwing: error)
            }
        }
    }
}

private extension Locale {
    static var homeAssistantTranslationIdentifier: String {
        Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first?.replacingOccurrences(of: "_", with: "-")
            ?? Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    }
}
#endif
