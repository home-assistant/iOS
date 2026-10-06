@testable import Shared
import Testing

/// Serialized because the tests share the database and swap the servers in `Current`.
@Suite(.serialized)
struct MagicItemProviderTests {
    private var sut: MagicItemProvider

    init() {
        self.sut = MagicItemProvider()
    }

    private static func entity(
        entityId: String,
        domain: String,
        name: String,
        icon: String?,
        serverId: String = "1"
    ) -> HAAppEntity {
        .init(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
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

    /// Two servers can hold the same entity id — two homes, each with a `cover.garage_door`. An item
    /// that can't be resolved must stay on its own server rather than being re-pointed at the
    /// identically named entity next door, and it must not drag the items that *did* resolve along
    /// with it.
    @Test mutating func migrateKeepsItemsOnTheirOwnServerWhenServersShareEntityIds() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }

        let servers = FakeServerManager()
        let firstServerId = servers.addFake().identifier.rawValue
        let secondServerId = servers.addFake().identifier.rawValue
        Current.servers = servers

        var carPlayConfig = CarPlayConfig()
        let expectedItems: [MagicItem] = [
            .init(id: "cover.garage_door", serverId: firstServerId, type: .entity),
            .init(id: "cover.garage_door", serverId: secondServerId, type: .entity),
            // Gone from the second server, so nothing resolves it: this is the item whose absence
            // used to send every other item to whichever server held its entity id first.
            .init(id: "light.gone", serverId: secondServerId, type: .entity),
        ]
        carPlayConfig.quickAccessItems = expectedItems

        try await Current.database().write { [carPlayConfig] db in
            try CarPlayConfig.deleteAll(db)
            try carPlayConfig.insert(db)
        }

        let garageDoorOnFirstServer = Self.entity(
            entityId: "cover.garage_door",
            domain: "cover",
            name: "Garage Door",
            icon: nil,
            serverId: firstServerId
        )
        let garageDoorOnSecondServer = Self.entity(
            entityId: "cover.garage_door",
            domain: "cover",
            name: "Garage Door",
            icon: nil,
            serverId: secondServerId
        )
        sut.entitiesPerServer = [
            firstServerId: [garageDoorOnFirstServer],
            secondServerId: [garageDoorOnSecondServer],
        ]

        await withCheckedContinuation { continuation in
            sut.migrateCarPlayConfig {
                continuation.resume()
            }
        }

        // `MagicItem`'s equality compares id, serverId and type, so this asserts the server each
        // item points at is untouched.
        let newCarPlayConfig = try CarPlayConfig.config()
        #expect(newCarPlayConfig?.quickAccessItems == expectedItems)
    }

    /// Items that aren't entity-backed have no entity to be re-pointed at, so an area or a
    /// complication that no longer resolves is kept as it is rather than dropped or moved.
    @Test mutating func migrateKeepsNonEntityBackedItemsThatCannotResolve() async throws {
        var watchConfig = WatchConfig()
        let expectedItems: [MagicItem] = [
            .init(id: "area-gone", serverId: "areas-test-server", type: .area),
            .init(id: "complication-gone", serverId: "areas-test-server", type: .complication),
        ]
        watchConfig.items = expectedItems

        try await Current.database().write { [watchConfig] db in
            try WatchConfig.deleteAll(db)
            try watchConfig.insert(db)
        }

        await withCheckedContinuation { continuation in
            sut.migrateWatchConfig {
                continuation.resume()
            }
        }

        let newWatchConfig = try WatchConfig.config()
        #expect(newWatchConfig?.items == expectedItems)
    }

    /// Entities cached for a server that has since been removed must not linger: the absence of a
    /// server's entities is what tells the migration an item's server is gone and its entity can be
    /// looked for elsewhere.
    @Test mutating func loadInformationForgetsServersThatAreNoLongerConfigured() async {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }

        let servers = FakeServerManager()
        let server = servers.addFake()
        Current.servers = servers

        let entityOnRemovedServer = Self.entity(
            entityId: "light.one",
            domain: "light",
            name: "Light One",
            icon: nil,
            serverId: "removed-server"
        )
        sut.entitiesPerServer = ["removed-server": [entityOnRemovedServer]]

        _ = await sut.loadInformation()

        #expect(sut.entitiesPerServer["removed-server"] == nil)
        #expect(sut.entitiesPerServer[server.identifier.rawValue] != nil)
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
