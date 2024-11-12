@testable import Shared
import Testing

struct MagicItemProviderTests {
    private var sut: MagicItemProvider

    init() {
        self.sut = MagicItemProvider()
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

        try await Current.database.write { [watchConfig, carPlayConfig] db in
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
                    icon: nil
                ),
                .init(
                    id: "2-scene.one",
                    entityId: "scene.one",
                    serverId: "2",
                    domain: "scene",
                    name: "Scene One",
                    icon: nil
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
            .init(id: "light.one", serverId: "2", type: .entity),
        ])

        #expect(newCarPlayConfig?.quickAccessItems == [
            .init(id: "script.one", serverId: "2", type: .script),
            .init(id: "scene.one", serverId: "2", type: .scene),
            .init(id: "light.one", serverId: "2", type: .entity),
        ])
    }
}
