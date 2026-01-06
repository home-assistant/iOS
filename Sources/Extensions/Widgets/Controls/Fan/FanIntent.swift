import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct FanIntent: SetValueIntent {
    static var title: LocalizedStringResource = .init("app_intents.intent.fan.title", defaultValue: "Control fan")

    @Parameter(title: .init("app_intents.fan.title", defaultValue: "Fan"))
    var fan: IntentFanEntity

    @Parameter(title: .init("app_intents.state.target", defaultValue: "Target state"))
    var value: Bool

    @Parameter(title: .init("app_intents.state.toggle", defaultValue: "Toggle"), default: false)
    var toggle: Bool

    func perform() async throws -> some IntentResult {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == fan.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result()
        }

        var service = Service.toggle.rawValue
        if !toggle {
            service = value ? Service.turnOn.rawValue : Service.turnOff.rawValue
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.fan.rawValue),
                service: .init(stringLiteral: service),
                data: [
                    "entity_id": fan.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }
        return .result()
    }
}
