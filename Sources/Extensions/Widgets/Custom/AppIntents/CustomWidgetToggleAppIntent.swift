import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 16.4, *)
struct CustomWidgetToggleAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle"
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
        await withCheckedContinuation { continuation in
            connection.send(.toggleDomain(domain: domain, entityId: entityId)).promise.pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume()
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to execute ToggleAppIntent, serverId: \(serverId), domain: \(domain), entityId: \(entityId), error: \(error)"
                        )
                    let dispatcher = LocalNotificationDispatcher()
                    dispatcher.send(.init(
                        id: .intentToggleFailed,
                        title: L10n.Widgets.Custom.IntentToggleFailed.title,
                        body: L10n.Widgets.Custom.IntentToggleFailed.body
                    ))
                    continuation.resume()
                }
            }
        }
        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()

        /* Since several entities when toggled may not report the correct state right away
         This is a workaround to refresh the widget a little later
         In theory through push notification we could always ask the widget to update through
         and automation/blueprint etc, but it's currently not reliable https://developer.apple.com/forums/thread/773852 */
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.custom.rawValue)
        }
        return .result()
    }
}
