import Foundation
import PromiseKit
import Shared

/// Delivers a notification action to Home Assistant from the watch.
///
/// The paired iPhone does the work whenever it is immediately reachable — it already holds the
/// connection and the session — and the watch falls back to its own webhook otherwise, which is what
/// keeps actions working when the phone is away (e.g. the watch on LTE).
enum WatchPushActionSender {
    enum SendError: LocalizedError {
        /// The phone took the action but could not deliver it (see `WatchCommunicatorService`).
        case phoneReportedFailure(String?)

        var errorDescription: String? {
            switch self {
            case let .phoneReportedFailure(reason):
                return "iPhone could not deliver the notification action" + (reason.map { ": \($0)" } ?? "")
            }
        }
    }

    /// Resumes a continuation at most once. The connectivity layer's reply timeout fires the error
    /// handler without cancelling the send, so a late reply can still arrive behind it — and a
    /// second resume of a `CheckedContinuation` traps.
    private final class SingleResume {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Error>?

        init(_ continuation: CheckedContinuation<Void, Error>) {
            self.continuation = continuation
        }

        func resume(throwing error: Error? = nil) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()

            guard let pending else { return }
            if let error {
                pending.resume(throwing: error)
            } else {
                pending.resume()
            }
        }
    }

    @MainActor
    static func send(_ info: HomeAssistantAPI.PushActionInfo, server: Server) async throws {
        if Communicator.shared.currentReachability == .immediatelyReachable {
            Current.Log.info("sending push action via phone")
            try await sendViaPhone(info, server: server)
        } else if let api = Current.api(for: server) {
            Current.Log.info("sending push action via local")
            try await api.handlePushAction(for: info).asyncValue()
        } else {
            // Throwing rather than returning: reporting success here would tell the caller a reply
            // went through when nothing was ever sent.
            Current.Log.error("no API available to send push action to \(server.identifier.rawValue)")
            throw HomeAssistantAPI.APIError.noAPIAvailable
        }
    }

    @MainActor
    private static func sendViaPhone(_ info: HomeAssistantAPI.PushActionInfo, server: Server) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resume = SingleResume(continuation)

            Communicator.shared.send(.init(
                identifier: InteractiveImmediateMessages.pushAction.rawValue,
                content: ["PushActionInfo": info.toJSON(), "Server": server.identifier.rawValue],
                reply: { message in
                    // The phone answers whether Home Assistant actually took the action. Phones
                    // older than that reply answer with no content at all, so only an explicit
                    // `false` counts as a failure and an old phone still reads as delivered.
                    guard message.content["fired"] as? Bool != false else {
                        resume.resume(
                            throwing: SendError.phoneReportedFailure(message.content["error"] as? String)
                        )
                        return
                    }
                    resume.resume()
                }
            ), errorHandler: { error in
                Current.Log.error("Received error when sending immediate message \(error)")
                resume.resume(throwing: error)
            })
        }
    }
}
