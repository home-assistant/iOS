import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct SwitchIntent: SetValueIntent {
    static var title: LocalizedStringResource = .init("app_intents.intent.switch.title", defaultValue: "Control switch")

    @Parameter(title: .init("app_intents.lights.light.title", defaultValue: "Light"))
    var entity: IntentSwitchEntity

    @Parameter(title: .init("app_intents.lights.light.target", defaultValue: "Target state"))
    var value: Bool

    @Parameter(title: .init("app_intents.state.toggle", defaultValue: "Toggle"), default: false)
    var toggle: Bool

    func perform() async throws -> some IntentResult {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == entity.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        var service = HAServices.toggle
        if !toggle {
            service = value ? HAServices.turnOn : HAServices.turnOff
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.switch.rawValue),
                service: .init(stringLiteral: service),
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
