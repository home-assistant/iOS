import Communicator
import Foundation
import ObjectMapper
import PromiseKit

public class WatchPushActionService: WatchCommunicationProtocol {
    public func handle(message: InteractiveImmediateMessage) {
        Current.Log.verbose("Received PushAction \(message) \(message.content)")
        let responseIdentifier = "PushActionResponse"

        if let infoJSON = message.content["PushActionInfo"] as? [String: Any],
           let info = Mapper<HomeAssistantAPI.PushActionInfo>().map(JSON: infoJSON),
           let serverIdentifier = message.content["Server"] as? String,
           let server = Current.servers.server(forServerIdentifier: serverIdentifier) {
            Current.backgroundTask(withName: "watch-push-action") { _ in
                firstly {
                    Current.api(for: server).handlePushAction(for: info)
                }.ensure {
                    message.reply(.init(identifier: responseIdentifier))
                }
            }.catch { error in
                Current.Log.error("error handling push action: \(error)")
            }
        }
    }
}
