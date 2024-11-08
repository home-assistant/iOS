import GRDB
@testable import Shared
import Testing

struct CarPlayConfigTests {
    @Test func validateCarPlayConfigScheme() async throws {
        let currentFileURL = URL(fileURLWithPath: #file)
        let directoryURL = currentFileURL.deletingLastPathComponent()
        let sqliteFileURL = directoryURL.appendingPathComponent("CarPlayConfigV1.sqlite")
        let database = try DatabaseQueue(path: sqliteFileURL.path)
        let carPlayConfig = try await database.read { db in
            try CarPlayConfig.fetchOne(db)
        }

        #expect(carPlayConfig?.id == "carplay-config", "CarPlay config id is wrong")
        #expect(carPlayConfig?.tabs == [
            .quickAccess,
            .areas,
            .domains,
        ], "CarPlay config tabs is wrong")
        #expect(carPlayConfig?.quickAccessItems == [
            .init(
                id: "script.new_script_2",
                serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
                type: .script,
                customization: .init(
                    iconColor: "00AEF8",
                    requiresConfirmation: true
                )
            ),
            .init(
                id: "script.new_script_5",
                serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
                type: .script,
                customization: .init(
                    iconColor: "00AEF8",
                    textColor: "#FFFFFFFF",
                    backgroundColor: "#000000FF",
                    requiresConfirmation: false
                )
            ),
        ], "CarPlay config has wrong items config")
    }
}
