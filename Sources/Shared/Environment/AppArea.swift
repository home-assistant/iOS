import Foundation
import GRDB
import HAKit

// `AppArea` itself lives in the `HAModels` package; this maps the websocket registry payload.
public extension AppArea {
    init(
        from area: HAAreasRegistryResponse,
        serverId: String,
        entities: Set<String>?,
        sortOrder: Int?,
        floorName: String? = nil
    ) {
        self.init(
            id: "\(serverId)-\(area.areaId)",
            serverId: serverId,
            areaId: area.areaId,
            name: area.name,
            aliases: area.aliases,
            picture: area.picture,
            icon: area.icon,
            sortOrder: sortOrder,
            entities: entities ?? [],
            floorId: area.floorId,
            floorName: floorName
        )
    }
}
