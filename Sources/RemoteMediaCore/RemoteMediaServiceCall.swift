import Foundation

/// The `media_player` service call one Now Playing control stands for.
///
/// Built from the command alone: the session attributes already decided which controls iOS shows,
/// so the extension does not fetch entity state to re-derive them. The host app's next state update
/// remains authoritative.
public struct RemoteMediaServiceCall: Equatable, Sendable {
    public let domain = "media_player"
    public let service: String
    public let serviceData: [String: RemoteMediaServiceValue]

    public init(command: RemoteMediaCommand, entityId: String, value: Double? = nil) throws {
        self.service = command.service
        var data: [String: RemoteMediaServiceValue] = ["entity_id": .string(entityId)]
        switch command {
        case .seek:
            guard let value, value.isFinite else { throw RemoteMediaError.invalidCommand }
            data["seek_position"] = .number(max(0, value))
        case .volume:
            guard let value, value.isFinite else { throw RemoteMediaError.invalidCommand }
            data["volume_level"] = .number(min(1, max(0, value)))
        case .play, .pause, .togglePlayPause, .stop, .previous, .next:
            break
        }
        self.serviceData = data
    }

    /// The `call_service` webhook payload's `data` value.
    public var webhookData: [String: Any] {
        [
            "domain": domain,
            "service": service,
            "service_data": serviceData.mapValues(\.jsonValue),
        ]
    }
}
