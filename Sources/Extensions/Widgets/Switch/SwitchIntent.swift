import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct SwitchIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Turn on/off switch"

    @Parameter(title: .init("app_intents.lights.light.title", defaultValue: "Light"))
    var entity: IntentSwitchEntity

    @Parameter(title: .init("app_intents.lights.light.target", defaultValue: "Target state"))
    var value: Bool

    func perform() async throws -> some IntentResult {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == entity.serverId }) else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            Current.api(for: server).connection.send(.callService(
                domain: .init(stringLiteral: Domain.switch.rawValue),
                service: .init(stringLiteral: value ? "turn_on" : "turn_off"),
                data: [
                    "entity_id": entity.entityId,
                ]
            )).promise.pipe { result in
                print(result)
                continuation.resume()
            }
        }
        return .result()
    }
}
