@testable import Shared
import Testing

struct MagicItemProviderTests {
    private var sut: MagicItemProvider

    init() {
        self.sut = MagicItemProvider()
    }

    private static func entity(entityId: String, domain: String, name: String, icon: String?) -> HAAppEntity {
        .init(
            id: "1-\(entityId)",
            entityId: entityId,
            serverId: "1",
            domain: domain,
            name: name,
            icon: icon,
            rawDeviceClass: ""
        )
    }

    @Test mutating func migrateWatchItemsIfCurrentServerIdDoestMatchServersAvailable() async throws {
        var watchConfig = WatchConfig()
        var carPlayConfig = CarPlayConfig()

        watchConfig.items = [
            .init(id: "script.one", serverId: "1", type: .script),
            .init(id: "scene.one", serverId: "1", type: .scene),
            .init(id: "light.one", serverId: "1", type: .entity),
        ]

        carPlayConfig.quickAccessItems = [
            .init(id: "script.one", serverId: "1", type: .script),
            .init(id: "scene.one", serverId: "1", type: .scene),
            .init(id: "light.one", serverId: "1", type: .entity),
        ]

        try await Current.database().write { [watchConfig, carPlayConfig] db in
            try WatchConfig.deleteAll(db)
            try CarPlayConfig.deleteAll(db)
            try watchConfig.insert(db)
            try carPlayConfig.insert(db)
        }

        #expect(try! WatchConfig.config()?.items == [
            .init(id: "script.one", serverId: "1", type: .script),
            .init(id: "scene.one", serverId: "1", type: .scene),
            .init(id: "light.one", serverId: "1", type: .entity),
        ])

        #expect(try! CarPlayConfig.config()?.quickAccessItems == [
            .init(id: "script.one", serverId: "1", type: .script),
            .init(id: "scene.one", serverId: "1", type: .scene),
            .init(id: "light.one", serverId: "1", type: .entity),
        ])

        // Defining current scripts and scenes that are in the database
        sut.entitiesPerServer = [
            "2": [
                .init(
                    id: "2-script.one",
                    entityId: "script.one",
                    serverId: "2",
                    domain: "script",
                    name: "Script One",
                    icon: nil,
                    rawDeviceClass: ""
                ),
                .init(
                    id: "2-scene.one",
                    entityId: "scene.one",
                    serverId: "2",
                    domain: "scene",
                    name: "Scene One",
                    icon: nil,
                    rawDeviceClass: ""
                ),
            ],
        ]

        await withCheckedContinuation { continuation in
            sut.migrateWatchConfig {
                continuation.resume()
            }
        }

        await withCheckedContinuation { continuation in
            sut.migrateCarPlayConfig {
                continuation.resume()
            }
        }

        let newWatchConfig = try WatchConfig.config()
        let newCarPlayConfig = try CarPlayConfig.config()

        #expect(newWatchConfig?.items == [
            .init(id: "script.one", serverId: "2", type: .script),
            .init(id: "scene.one", serverId: "2", type: .scene),
            // No replacement provided so item stays the same
            .init(id: "light.one", serverId: "1", type: .entity),
        ])

        #expect(newCarPlayConfig?.quickAccessItems == [
            .init(id: "script.one", serverId: "2", type: .script),
            .init(id: "scene.one", serverId: "2", type: .scene),
            // No replacement provided so item stays the same
            .init(id: "light.one", serverId: "1", type: .entity),
        ])
    }

    /// `getInfo` resolves entity-backed items through the per-server entity index rather than scanning
    /// the entity list, which is what keeps resolving a whole picker's worth of items linear.
    @Test mutating func getInfoResolvesEntityBackedItemsThroughTheIndex() {
        sut.entitiesPerServer = [
            "1": [
                Self.entity(entityId: "light.one", domain: "light", name: "Light One", icon: "mdi:lightbulb"),
                Self.entity(entityId: "script.one", domain: "script", name: "Script One", icon: "mdi:script"),
                Self.entity(entityId: "scene.one", domain: "scene", name: "Scene One", icon: "mdi:palette"),
            ],
        ]

        let entityInfo = sut.getInfo(for: .init(id: "light.one", serverId: "1", type: .entity))
        #expect(entityInfo?.id == "1-light.one")
        #expect(entityInfo?.name == "Light One")
        #expect(entityInfo?.iconName == "mdi:lightbulb")

        let scriptInfo = sut.getInfo(for: .init(id: "script.one", serverId: "1", type: .script))
        #expect(scriptInfo?.id == "1-script.one")
        #expect(scriptInfo?.name == "Script One")

        let sceneInfo = sut.getInfo(for: .init(id: "scene.one", serverId: "1", type: .scene))
        #expect(sceneInfo?.id == "1-scene.one")
        #expect(sceneInfo?.name == "Scene One")
    }

    @Test mutating func getInfoReturnsNilWhenEntityIsMissingOrDomainDoesNotMatchItemType() {
        sut.entitiesPerServer = [
            "1": [Self.entity(entityId: "light.one", domain: "light", name: "Light One", icon: "mdi:lightbulb")],
        ]

        #expect(sut.getInfo(for: .init(id: "light.two", serverId: "1", type: .entity)) == nil)
        // Right entity id, but on a server the provider knows nothing about.
        #expect(sut.getInfo(for: .init(id: "light.one", serverId: "2", type: .entity)) == nil)
        // The id exists, just not as a script/scene: the lookups stay domain-aware.
        #expect(sut.getInfo(for: .init(id: "light.one", serverId: "1", type: .script)) == nil)
        #expect(sut.getInfo(for: .init(id: "light.one", serverId: "1", type: .scene)) == nil)
    }

    @Test mutating func migrateWatchAssistItemsNormalizesUnsupportedCustomization() async throws {
        var watchConfig = WatchConfig()
        watchConfig.items = [
            .init(
                id: "pipeline.one",
                serverId: "1",
                type: .assistPipeline,
                customization: .init(requiresConfirmation: true)
            ),
        ]

        try await Current.database().write { [watchConfig] db in
            try WatchConfig.deleteAll(db)
            try watchConfig.insert(db)
        }

        await withCheckedContinuation { continuation in
            sut.migrateWatchConfig {
                continuation.resume()
            }
        }

        // Assist opens a voice session instead of calling a service, so it never confirms and always
        // carries the Assist icon color.
        let item = try WatchConfig.config()?.items.first
        #expect(item?.type == .assistPipeline)
        #expect(item?.customization?.requiresConfirmation == false)
        #expect(item?.customization?.iconColor == MagicItem.defaultAssistIconColorHex)
    }

    @Test mutating func migrateCarPlayAssistItemsNormalizesUnsupportedCustomization() async throws {
        var carPlayConfig = CarPlayConfig()
        carPlayConfig.quickAccessItems = [
            .init(
                id: "pipeline.one",
                serverId: "1",
                type: .assistPipeline,
                customization: .init(requiresConfirmation: true)
            ),
        ]

        try await Current.database().write { [carPlayConfig] db in
            try CarPlayConfig.deleteAll(db)
            try carPlayConfig.insert(db)
        }

        await withCheckedContinuation { continuation in
            sut.migrateCarPlayConfig {
                continuation.resume()
            }
        }

        let newCarPlayConfig = try CarPlayConfig.config()
        #expect(newCarPlayConfig?.quickAccessItems == [
            .init(
                id: "pipeline.one",
                serverId: "1",
                type: .assistPipeline,
                customization: .init(
                    iconColor: MagicItem.defaultAssistIconColorHex,
                    requiresConfirmation: false
                )
            ),
        ])
    }
}
