import AppIntents
import Foundation
import Shared
import SwiftUI

@available(iOS 16.4, *)
struct CustomWidgetPressButtonAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle"
    static var isDiscoverable: Bool = false

    // No translation needed below, this is not a discoverable intent
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
        AppIntentHaptics.notify()
        await withCheckedContinuation { continuation in
            connection.send(.pressButton(domain: domain, entityId: entityId)).promise.pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume()
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to execute PressButtonAppIntent, serverId: \(serverId), domain: \(domain), entityId: \(entityId), error: \(error)"
                        )
                    AppIntentNotificationHelper.showConfirmation(
                        id: .intentPressFailed,
                        title: L10n.Widgets.Custom.IntentPressFailed.title,
                        body: L10n.Widgets.Custom.IntentPressFailed.body,
                        isSuccess: false,
                        duration: 4.0
                    )
                    continuation.resume()
                }
            }
        }
        _ = try await ResetAllCustomWidgetConfirmationAppIntent().perform()
        return .result()
    }
}
