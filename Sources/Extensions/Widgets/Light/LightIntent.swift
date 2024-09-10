import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct LightIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Turn on/off light"

    @Parameter(title: .init("app_intents.lights.light.title", defaultValue: "Light"))
    var light: IntentLightEntity

    @Parameter(title: .init("app_intents.lights.light.target", defaultValue: "Target state"))
    var value: Bool

    func perform() async throws -> some IntentResult {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == light.serverId }) else {
            return .result()
        }

        let _ = await withCheckedContinuation { continuation in
            Current.api(for: server).connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: value ? "turn_on" : "turn_off"),
                data: [
                    "entity_id": light.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }
        return .result()
    }
}
