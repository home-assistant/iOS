import GRDB
@testable import Shared

/// A small cached home for the in-car add/edit flows: entities the flow should offer, entities it
/// must leave out (unsupported domain, configuration, hidden, another server), two areas with
/// something to add and one without, and the server's Assist pipelines.
enum CarPlayAddItemFixture {
    static let kitchenAreaId = "kitchen"
    static let garageAreaId = "garage"
    static let preferredPipelineId = "pipeline-preferred"
    static let otherPipelineId = "pipeline-other"

    static func seed(in database: DatabaseQueue, serverId: String, otherServerId: String = "other-server") throws {
        try database.write { db in
            for entity in [
                appEntity("light.kitchen", serverId: serverId, name: "Kitchen light"),
                appEntity("cover.garage_door", serverId: serverId, name: "Garage door"),
                appEntity("lock.front_door", serverId: serverId, name: "Front door"),
                appEntity("climate.hall", serverId: serverId, name: "Hall thermostat"),
                appEntity("sensor.temperature", serverId: serverId, name: "Temperature"),
                appEntity("switch.config_option", serverId: serverId, name: "Config option"),
                appEntity("light.hidden", serverId: serverId, name: "Hidden light"),
                appEntity("light.elsewhere", serverId: otherServerId, name: "Elsewhere light"),
            ] {
                try entity.insert(db)
            }

            try EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: "switch.config_option",
                entityCategory: 0
            ).insert(db)
            try EntityRegistryListForDisplay.Entity(
                serverId: serverId,
                entityId: "light.hidden",
                hidden: true
            ).insert(db)

            try area(
                kitchenAreaId,
                serverId: serverId,
                name: "Kitchen",
                sortOrder: 0,
                entities: ["light.kitchen", "sensor.temperature", "light.hidden"]
            ).insert(db)
            try area(
                garageAreaId,
                serverId: serverId,
                name: "Garage",
                sortOrder: 1,
                entities: ["cover.garage_door", "lock.front_door"]
            ).insert(db)
            try area(
                "attic",
                serverId: serverId,
                name: "Attic",
                sortOrder: 2,
                entities: ["sensor.temperature"]
            ).insert(db)

            try AssistPipelines(
                serverId: serverId,
                preferredPipeline: preferredPipelineId,
                pipelines: [
                    Pipeline(id: preferredPipelineId, name: "Home", sttEngine: "stt.cloud", ttsEngine: "tts.cloud"),
                    Pipeline(id: otherPipelineId, name: "Local", sttEngine: "stt.local", ttsEngine: "tts.local"),
                    Pipeline(id: "pipeline-text-only", name: "Text only", sttEngine: nil, ttsEngine: " "),
                ]
            ).insert(db)
        }
    }

    static func appEntity(_ entityId: String, serverId: String, name: String, icon: String? = nil) -> HAAppEntity {
        HAAppEntity(
            id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
            entityId: entityId,
            serverId: serverId,
            domain: String(entityId.split(separator: ".")[0]),
            name: name,
            icon: icon,
            rawDeviceClass: nil
        )
    }

    static func area(
        _ areaId: String,
        serverId: String,
        name: String,
        sortOrder: Int,
        entities: Set<String>
    ) -> AppArea {
        AppArea(
            id: "\(serverId)-\(areaId)",
            serverId: serverId,
            areaId: areaId,
            name: name,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: sortOrder,
            entities: entities
        )
    }
}
