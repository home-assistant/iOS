import Foundation
import HAKit
import PromiseKit
import Shared

/// Validates a long-lived access token against a server's live REST API before the token-bearing
/// path trusts it. Abstracted so tests can drive the runner without a network.
protocol ServerTokenValidating {
    /// Returns normally when `GET <externalURL>/api/` with a bearer token answers as an authenticated
    /// Home Assistant; throws otherwise (bad token, unreachable, non-HA response).
    func validate(token: String, externalURL: URL) async throws
}

/// Adds a server whose access token came from the file, with no login. Abstracted so tests can assert
/// what would be added without a network or the keychain.
protocol ServerConfigurationPersisting {
    /// The external URLs of servers already configured, used for dedupe.
    var existingServers: [(name: String, externalURL: URL?)] { get }
    /// Runs the authenticated setup for the server (mobile app registration and the rest of what
    /// sign-in does once it holds a token), then persists it. Throws if any step fails, in which case
    /// nothing is persisted. Returns the identifier the server was stored under.
    @discardableResult
    func add(entry: ServerConfigurationImport.ServerEntry, token: String) async throws -> Identifier<Server>
}

/// Drives a decoded document: validates tokens, adds the automatic servers, and reports which
/// token-less servers still need the guided sign-in flow. The guided servers are returned rather than
/// onboarded here, because onboarding is a UI flow the presenter owns — this type stays free of UI so
/// it can be tested headlessly.
struct ServerConfigurationImportRunner {
    let tokenValidator: ServerTokenValidating
    let persistence: ServerConfigurationPersisting

    init(
        tokenValidator: ServerTokenValidating = HAServerTokenValidator(),
        persistence: ServerConfigurationPersisting = LiveServerConfigurationPersistence()
    ) {
        self.tokenValidator = tokenValidator
        self.persistence = persistence
    }

    /// Result of a run: every outcome (in document order) plus the entries that must now be walked
    /// through guided sign-in, in order.
    struct Summary: Equatable {
        var outcomes: [ServerConfigurationImport.ServerOutcome]
        var guidedServers: [ServerConfigurationImport.ServerEntry]

        var addedCount: Int { outcomes.filter { $0.result == .added }.count }
        var skippedCount: Int {
            outcomes.filter { if case .skipped = $0.result { return true } else { return false } }.count
        }

        var failedCount: Int {
            outcomes.filter { if case .failed = $0.result { return true } else { return false } }.count
        }

        var guidedCount: Int { guidedServers.count }
    }

    /// Adds every token-bearing server and collects the token-less ones for the guided path, skipping
    /// servers already configured on this device.
    ///
    /// Each URL is acted on once per run: after one entry for a URL is added or queued for sign-in,
    /// later entries for the same URL are skipped. An entry that failed doesn't count, so a later
    /// entry for that URL still gets its own attempt.
    ///
    /// Cancelling the surrounding task stops the run before the next server is written; servers not
    /// reached are reported as skipped.
    func run(_ document: ServerConfigurationImport.Document) async -> Summary {
        var outcomes = ServerConfigurationImport.classify(
            document,
            existingServers: persistence.existingServers
        )

        var guidedServers: [ServerConfigurationImport.ServerEntry] = []
        var handledKeys = Set<String>()

        for index in outcomes.indices {
            let outcome = outcomes[index]
            let entry = outcome.entry
            let key = ServerConfigurationImport.normalizedKey(for: entry.externalURL)

            if case let .duplicate(existingName) = outcome.classification {
                outcomes[index].result = .skipped(reason: L10n.ImportServers.Skipped.duplicate(existingName))
                continue
            }
            guard !handledKeys.contains(key) else {
                outcomes[index].result = .skipped(reason: L10n.ImportServers.Skipped.repeatedInFile)
                continue
            }
            guard !Task.isCancelled else {
                outcomes[index].result = .skipped(reason: L10n.ImportServers.Skipped.cancelled)
                continue
            }

            guard let token = entry.longLivedAccessToken else {
                guidedServers.append(entry)
                outcomes[index].result = .awaitingGuidedSignIn
                handledKeys.insert(key)
                continue
            }

            do {
                try await tokenValidator.validate(token: token, externalURL: entry.externalURL)
                // The last point a cancelled import can stop without having written anything.
                guard !Task.isCancelled else {
                    outcomes[index].result = .skipped(reason: L10n.ImportServers.Skipped.cancelled)
                    continue
                }
                try await persistence.add(entry: entry, token: token)
                outcomes[index].result = .added
                handledKeys.insert(key)
            } catch {
                outcomes[index].result = .failed(reason: error.localizedDescription)
            }
        }

        return Summary(outcomes: outcomes, guidedServers: guidedServers)
    }
}

// MARK: - Live token validator

/// Verifies a token by calling `GET <externalURL>/api/` with `Authorization: Bearer <token>`. An
/// authenticated Home Assistant answers that with a 200 and `{"message": "API running."}`, and a bad
/// token with 401. Any other answer, including a 2xx from something that isn't Home Assistant (an
/// authenticating proxy's HTML login page, an empty 204), is rejected.
struct HAServerTokenValidator: ServerTokenValidating {
    enum ValidationError: LocalizedError, Equatable {
        case notAnHTTPResponse
        case unauthorized
        case unexpectedStatus(Int)
        case notHomeAssistant

        var errorDescription: String? {
            switch self {
            case .notAnHTTPResponse:
                return L10n.ImportServers.Error.tokenResponseInvalid
            case .unauthorized:
                return L10n.ImportServers.Error.tokenRejected
            case let .unexpectedStatus(code):
                return L10n.ImportServers.Error.tokenUnexpectedStatus(code)
            case .notHomeAssistant:
                return L10n.ImportServers.Error.notHomeAssistant
            }
        }
    }

    /// What Home Assistant's `/api/` endpoint reports when the request is authenticated.
    static let apiRunningMessage = "API running."

    /// Short timeout so a wrong/unreachable URL in the file fails fast rather than hanging the import.
    var timeout: TimeInterval = 20

    /// Performs the request. Injectable so tests can answer with canned responses.
    var load: (URLRequest) async throws -> (Data, URLResponse) = { request in
        try await URLSession.shared.data(for: request)
    }

    /// `<externalURL>/api/`, keeping the trailing slash the endpoint is registered under.
    static func apiURL(for externalURL: URL) -> URL {
        externalURL.appendingPathComponent("api", isDirectory: true)
    }

    func validate(token: String, externalURL: URL) async throws {
        var request = URLRequest(url: Self.apiURL(for: externalURL))
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await load(request)
        try Self.evaluate(data: data, response: response)
    }

    /// Decides whether a response to `GET /api/` came from Home Assistant accepting the token.
    static func evaluate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ValidationError.notAnHTTPResponse
        }
        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw ValidationError.unauthorized
        default:
            throw ValidationError.unexpectedStatus(http.statusCode)
        }

        guard let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              body["message"] as? String == apiRunningMessage else {
            throw ValidationError.notHomeAssistant
        }
    }
}

// MARK: - Live persistence

/// Adds a server from a file entry through the same authenticated setup sign-in uses
/// (`OnboardingAuth.configure`): mobile app registration (which supplies the webhook ID and secret),
/// `get_config`, sensors and models, and only then `Current.servers.add`. An imported server is
/// therefore indistinguishable from one added by signing in, and a failure in any step leaves nothing
/// persisted.
struct LiveServerConfigurationPersistence: ServerConfigurationPersisting {
    var existingServers: [(name: String, externalURL: URL?)] {
        Current.servers.all.map { server in
            (
                name: server.info.name,
                externalURL: server.info.connection.urlForTroubleshooting(type: .external)
            )
        }
    }

    @discardableResult
    func add(entry: ServerConfigurationImport.ServerEntry, token: String) async throws -> Identifier<Server> {
        let server = try await Self.configure(entry: entry, token: token).asyncValue()
        Current.appDatabaseUpdater.update(server: server, forceUpdate: true, showProgress: false)
        return server.identifier
    }

    @MainActor
    private static func configure(entry: ServerConfigurationImport.ServerEntry, token: String) -> Promise<Server> {
        var serverInfo = makeServerInfo(entry: entry, token: token)
        // Held in memory until setup succeeds, like sign-in's own server; `configure` persists it under
        // the instance ID `get_config` reports.
        let server = Server(
            identifier: Identifier<Server>(rawValue: UUID().uuidString),
            getter: { serverInfo },
            setter: { serverInfo = $0; return true }
        )
        let isFirstServer = Current.servers.all.isEmpty

        return OnboardingAuth().configure(
            api: HomeAssistantAPI(server: server),
            // Nothing is on screen to answer a question with, so steps that would ask decide on their own.
            presenter: OnboardingAuthPresenter(isInteractive: false),
            // The user made this token for the import; a failed setup must not revoke it.
            revokesTokenOnFailure: false
        ).get { _ in
            if isFirstServer {
                // Same as a first sign-in: every sensor is opt-in on a fresh install.
                Current.sensors.resetSensorsForFirstRun()
            }
        }
    }

    /// Assembles the in-memory `ServerInfo` setup starts from. Factored out (and static) so a test can
    /// assert the shape without a keychain. The token is long-lived, so the stored expiration is set
    /// far in the future; it has no refresh token, which is exactly how long-lived tokens behave. The
    /// webhook ID is filled in by registration before anything is persisted, and the file's name is
    /// kept as the local name so `get_config` reporting the server's own name doesn't replace it.
    static func makeServerInfo(entry: ServerConfigurationImport.ServerEntry, token: String) -> ServerInfo {
        let connection = ConnectionInfo(
            externalURL: entry.externalURL,
            internalURL: entry.internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined,
            clientCertificate: nil
        )

        let tokenInfo = TokenInfo(
            accessToken: token,
            // Long-lived tokens are not refreshed through the OAuth refresh flow; there is no refresh
            // token to store. The token manager treats an empty refresh token as "cannot refresh".
            refreshToken: "",
            expiration: .distantFuture
        )

        var serverInfo = ServerInfo(
            name: entry.name,
            connection: connection,
            token: tokenInfo,
            version: DiscoveredHomeAssistant.defaultVersion
        )
        serverInfo.setSetting(value: entry.name, for: .localName)
        return serverInfo
    }
}
