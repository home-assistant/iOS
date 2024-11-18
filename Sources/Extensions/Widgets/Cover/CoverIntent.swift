import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct CoverIntent: SetValueIntent {
    static var title: LocalizedStringResource = .init("app_intents.intent.cover.title", defaultValue: "Control cover")

    @Parameter(title: .init("app_intents.cover.title", defaultValue: "Cover"))
    var entity: IntentCoverEntity

    @Parameter(title: .init("app_intents.state.target", defaultValue: "Target state"))
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
            service = value ? HAServices.openCover : HAServices.closeCover
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
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
