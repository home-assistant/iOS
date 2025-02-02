import AppIntents
import Foundation
import HAKit
import Shared
import SwiftUI

@available(iOS 16.4, *)
/// Intent activate scenes or scripts
struct CustomWidgetActivateAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Server")
    var serverId: String?
    @Parameter(title: "Domain")
    var domain: String?
    @Parameter(title: "Entity ID")
    var entityId: String?

    func perform() async throws -> some IntentResult {
        guard let serverId,
              let domainString = domain,
              let domain = Domain(rawValue: domainString),
              let entityId,
              let server = Current.servers.all.first(where: { server in
                  server.identifier.rawValue == serverId
              }), let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        guard let request: HATypedRequest<HAResponseVoid> = {
            switch domain {
            case .script:
                return .runScript(entityId: entityId)
            case .scene:
                return .applyScene(entityId: entityId)
            default:
                Current.Log.error("Attempt to use ActivateAppIntent with unsupported domain \(domain)")
                return nil
            }
        }() else {
            return .result()
        }

        await withCheckedContinuation { continuation in
            connection.send(request).promise.pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume()
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to execute ActivateAppIntent, serverId: \(serverId), domain: \(domain), entityId: \(entityId), error: \(error)"
                        )
                    continuation.resume()
                }
            }
        }
        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()
        return .result()
    }
}
