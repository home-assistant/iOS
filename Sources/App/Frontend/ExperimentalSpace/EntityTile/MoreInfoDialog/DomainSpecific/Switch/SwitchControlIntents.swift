import AppIntents
import Foundation
import HAKit
import Shared

// MARK: - Toggle Switch Intent

@available(iOS 18, *)
struct ToggleSwitchIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Switch"
    static var isDiscoverable = false

    @Parameter(title: "Switch")
    var switchEntity: IntentSwitchEntity

    func perform() async throws -> some IntentResult {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == switchEntity.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.switch.rawValue),
                service: .init(rawValue: Service.toggle.rawValue),
                data: [
                    "entity_id": switchEntity.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return .result()
    }
}
