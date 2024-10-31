import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct CoverIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Open/Close Cover"

    @Parameter(title: .init("app_intents.lights.light.title", defaultValue: "Light"))
    var entity: IntentCoverEntity

    @Parameter(title: .init("app_intents.lights.light.target", defaultValue: "Target state"))
    var value: Bool

    @Parameter(title: .init("app_intents.lights.light.target", defaultValue: "Toggle"), default: false)
    var toggle: Bool

    func perform() async throws -> some IntentResult {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == entity.serverId }) else {
            return .result()
        }

        var service = "toggle"
        if !toggle {
            service = value ? "open_cover" : "close_cover"
        }

        let _ = await withCheckedContinuation { continuation in
            Current.api(for: server).connection.send(.callService(
                domain: .init(stringLiteral: Domain.cover.rawValue),
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
