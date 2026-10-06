import Foundation
import Shared

/// Logs this Apple Watch in to a server on its own, through Home Assistant's login flow.
///
/// The resulting token belongs to this watch alone: synced server snapshots from the iPhone never
/// replace it, so every watch has its own session that can be revoked from the Home Assistant profile
/// without signing out the iPhone or any other watch.
@MainActor
final class WatchServerLoginViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case chooseProvider([LoginFlowProvider])
        case form(LoginFlowStep)
        case failed(String)
        case loggedIn
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var isSubmitting = false
    /// Input for text, integer and select fields, keyed by field name.
    @Published var textValues: [String: String] = [:]
    /// Input for boolean fields, keyed by field name.
    @Published var boolValues: [String: Bool] = [:]

    let server: Server
    private let api: AuthenticationAPI
    /// Resolved once per flow: the server refuses to continue a flow from a different IP address.
    private var baseURL: URL?

    init(server: Server) {
        self.server = server
        self.api = AuthenticationAPI(server: server)
    }

    init(server: Server, previewState: State) {
        self.server = server
        self.api = AuthenticationAPI(server: server)
        self.state = previewState
    }

    func start() async {
        state = .loading
        textValues = [:]
        boolValues = [:]

        guard let baseURL = await server.activeURL() else {
            state = .failed(L10n.Watch.Settings.Login.Error.noUrl)
            return
        }
        self.baseURL = baseURL

        do {
            let providers = try await api.loginProviders(baseURL: baseURL)
            if providers.count == 1, let provider = providers.first {
                await choose(provider)
            } else if providers.isEmpty {
                state = .failed(L10n.Watch.Settings.Login.Error.noProviders)
            } else {
                state = .chooseProvider(providers)
            }
        } catch {
            fail(error)
        }
    }

    func choose(_ provider: LoginFlowProvider) async {
        guard let baseURL else { return }
        state = .loading
        do {
            try await handle(api.startLoginFlow(provider: provider, baseURL: baseURL))
        } catch {
            fail(error)
        }
    }

    func submit() async {
        guard let baseURL, case let .form(step) = state, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await handle(api.submitLoginFlow(flowID: step.flowID, input: input(for: step), baseURL: baseURL))
        } catch {
            fail(error)
        }
    }

    /// Whether every required field of the current form has a value.
    var canSubmit: Bool {
        guard case let .form(step) = state else { return false }
        return step.dataSchema.allSatisfy { field in
            !field.isRequired || field.type == "boolean" || !(textValues[field.name] ?? "").isEmpty
        }
    }

    /// The error the server reported for the last submission of the current form, if any.
    var formError: String? {
        guard case let .form(step) = state else { return nil }
        let code = step.errors["base"] ?? step.errors.values.sorted().first
        return code.map(Self.message(forError:))
    }

    static func label(for field: LoginFlowField) -> String {
        switch field.name {
        case "username": return L10n.Watch.Settings.Login.Field.username
        case "password": return L10n.Watch.Settings.Login.Field.password
        case "code": return L10n.Watch.Settings.Login.Field.code
        case "user": return L10n.Watch.Settings.Login.Field.user
        default: return field.name
        }
    }

    static func message(forError code: String) -> String {
        switch code {
        case "invalid_auth": return L10n.Watch.Settings.Login.Error.invalidAuth
        case "invalid_code": return L10n.Watch.Settings.Login.Error.invalidCode
        case "login_expired": return L10n.Watch.Settings.Login.Error.loginExpired
        default: return L10n.Watch.Settings.Login.Error.generic(code)
        }
    }

    private func input(for step: LoginFlowStep) -> [String: Any] {
        var input = [String: Any]()
        for field in step.dataSchema {
            if field.type == "boolean" {
                input[field.name] = boolValues[field.name] ?? false
                continue
            }
            guard let value = textValues[field.name], !value.isEmpty else { continue }
            if field.type == "integer", let number = Int(value) {
                input[field.name] = number
            } else {
                input[field.name] = value
            }
        }
        return input
    }

    private func handle(_ step: LoginFlowStep) async throws {
        switch step.kind {
        case .form:
            if case let .form(previous) = state, previous.stepID != step.stepID {
                // A new step (such as two-factor authentication) starts with empty fields.
                textValues = [:]
                boolValues = [:]
            }
            if let select = step.dataSchema.first(where: { $0.type == "select" }),
               textValues[select.name] == nil {
                textValues[select.name] = select.options.first?.value
            }
            state = .form(step)
        case .createEntry:
            guard let code = step.result, let baseURL else {
                state = .failed(L10n.Watch.Settings.Login.Error.generic(step.reason ?? "create_entry"))
                return
            }
            let token = try await api.token(authorizationCode: code, baseURL: baseURL)
            store(token)
            state = .loggedIn
        case .abort:
            state = .failed(Self.message(forError: step.reason ?? "abort"))
        case let .unknown(type):
            state = .failed(L10n.Watch.Settings.Login.Error.generic(type))
        }
    }

    private func store(_ token: TokenInfo) {
        Current.Log.info("[Watch] Logged in to \(server.identifier) on this watch")
        server.update { info in
            info.token = with(token) { $0.isIssuedToWatch = true }
        }
        // Reconnect with the new token, and hand it to the complication widget.
        Current.resetAPICache(for: [server.identifier])
        WatchWidgetComplicationSnapshotStore.update()
    }

    private func fail(_ error: Error) {
        Current.Log.error("[Watch] Login to \(server.identifier) failed: \(error)")
        state = .failed(L10n.Watch.Settings.Login.Error.generic(error.localizedDescription))
    }
}
