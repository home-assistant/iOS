import Foundation
import PromiseKit

/// Handles the `incoming_call` command once `IncomingCallRouting` has chosen CallKit for it.
///
/// Registered by the process that receives the command, each with its own way to ring:
/// - the PushProvider extension hands the call to the app with `NEAppPushProvider.reportIncomingCall(userInfo:)`,
///   which launches the app and makes it report the call to CallKit;
/// - the app reports the call to CallKit itself.
///
/// `payload` is the `homeassistant` dictionary, already checked: it is only ever passed on as received.
public struct IncomingCallCommandHandler: NotificationCommandHandler {
    public typealias Ring = (_ request: IncomingCallRequest, _ payload: [String: Any]) -> Void

    private let ring: Ring

    public init(ring: @escaping Ring) {
        self.ring = ring
    }

    public func handle(_ payload: [String: Any]) -> Promise<Void> {
        let server = (payload["webhook_id"] as? String).flatMap { Current.servers.server(forWebhookID: $0) }
        guard let server else {
            Current.Log.error("ignoring incoming call from an unknown server")
            return .init(error: IncomingCallRequest.ParseError.notIncomingCall)
        }

        let serverURLs = IncomingCallRouting.serverURLs(for: server)
        switch IncomingCallRequest.parse(homeassistant: payload, serverURLs: serverURLs) {
        case let .success(request):
            Current.Log.info("ringing incoming call \(request.tag)")
            ring(request, payload)
            return .value(())
        case let .failure(error):
            Current.Log.error("ignoring invalid incoming call: \(error)")
            return .init(error: error)
        }
    }
}
