import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct LightIntent: SetValueIntent {
    static var title: LocalizedStringResource = .init("app_intents.intent.light.title", defaultValue: "Control light")

    @Parameter(title: .init("app_intents.lights.light.title", defaultValue: "Light"))
    var light: IntentLightEntity

    @Parameter(title: .init("app_intents.lights.light.target", defaultValue: "Target state"))
    var value: Bool

    @Parameter(title: .init("app_intents.state.toggle", defaultValue: "Toggle"), default: false)
    var toggle: Bool

    func perform() async throws -> some IntentResult {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == light.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        var service = HAServices.toggle
        if !toggle {
            service = value ? HAServices.turnOn : HAServices.turnOff
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: service),
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
