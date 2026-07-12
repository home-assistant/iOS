import Foundation
import HANetworking

// Convenience `ServerManager` lookups that depend on `ServerIntentProviding` (→ `IntentServer`, from
// Intents) and `ServerIdentifierProviding`, which live in the Shared module. Kept here because the
// HANetworking package can't reach those types.
public extension ServerManager {
    private var fallbackServer: Server? {
        let all = all
        if all.count == 1, let server = all.first {
            return server
        } else {
            return nil
        }
    }

    func server(for providing: ServerIdentifierProviding, fallback: Bool = true) -> Server? {
        if let server = server(forServerIdentifier: providing.serverIdentifier) {
            return server
        } else if fallback {
            return fallbackServer
        } else {
            return nil
        }
    }

    func server(for intent: ServerIntentProviding, fallback: Bool = true) -> Server? {
        if let server = server(forServerIdentifier: intent.server?.identifier) {
            return server
        } else if fallback {
            return fallbackServer
        } else {
            return nil
        }
    }
}
