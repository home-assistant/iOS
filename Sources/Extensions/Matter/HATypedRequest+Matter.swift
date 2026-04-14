import HAKit
import Shared

struct MatterConfigEntry: Codable, HADataDecodable {
    let entryId: String
    let domain: String

    init(data: HAData) throws {
        self.entryId = try data.decode("entry_id")
        self.domain = try data.decode("domain")
    }
}

extension HATypedRequest {
    static func matterCommission(
        code: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "matter/commission",
            data: ["code": code]
        ))
    }

    static func configEntriesList() -> HATypedRequest<[MatterConfigEntry]> {
        HATypedRequest<[MatterConfigEntry]>(request: .init(
            type: "config_entries/get"
        ))
    }

    static func updateDeviceRegistry(
        deviceId: String,
        nameByUser: String
    ) -> HATypedRequest<DeviceRegistryEntry> {
        HATypedRequest<DeviceRegistryEntry>(request: .init(
            type: "config/device_registry/update",
            data: [
                "device_id": deviceId,
                "name_by_user": nameByUser,
            ]
        ))
    }
}
