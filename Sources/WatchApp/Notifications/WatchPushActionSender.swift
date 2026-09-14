import Foundation
import PromiseKit
import Shared

/// Delivers a notification action to Home Assistant from the watch.
///
/// The paired iPhone does the work whenever it is immediately reachable — it already holds the
/// connection and the session — and the watch falls back to its own webhook otherwise, which is what
/// keeps actions working when the phone is away (e.g. the watch on LTE).
enum WatchPushActionSender {
    static func send(_ info: HomeAssistantAPI.PushActionInfo, server: Server) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()

        if Communicator.shared.currentReachability == .immediatelyReachable {
            Current.Log.info("sending push action via phone")
            Communicator.shared.send(.init(
                identifier: InteractiveImmediateMessages.pushAction.rawValue,
                content: ["PushActionInfo": info.toJSON(), "Server": server.identifier.rawValue],
                reply: { message in
                    Current.Log.verbose("Received reply dictionary \(message)")
                    seal.fulfill(())
                }
            ), errorHandler: { error in
                Current.Log.error("Received error when sending immediate message \(error)")
                seal.reject(error)
            })
        } else if let api = Current.api(for: server) {
            Current.Log.info("sending push action via local")
            api.handlePushAction(for: info).pipe(to: seal.resolve)
        } else {
            // Rejecting rather than leaving the promise pending: a never-resolving promise here used
            // to mean the notification response's completion handler was never called either.
            Current.Log.error("no API available to send push action to \(server.identifier.rawValue)")
            seal.reject(HomeAssistantAPI.APIError.noAPIAvailable)
        }

        return promise
    }
}
