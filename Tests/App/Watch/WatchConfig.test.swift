import GRDB
@testable import Shared
import Testing

struct WatchConfig_test {
    @Test func validateWatchConfigScheme() async throws {
        let currentFileURL = URL(fileURLWithPath: #file)
        let directoryURL = currentFileURL.deletingLastPathComponent()
        let sqliteFileURL = directoryURL.appendingPathComponent("WatchConfigV1.sqlite")
        let database = try DatabaseQueue(path: sqliteFileURL.path)
        let watchConfig = try await database.read { db in
            try WatchConfig.fetchOne(db)
        }

        #expect(watchConfig?.id == "0CFEB349-EDA9-4F79-A5F9-326495552E27", "Watch config has wrong ID")
        #expect(watchConfig?.assist == WatchConfig.Assist(
            showAssist: true,
            serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
            pipelineId: "01j4khbxmamfcpqbes3d6zxm5b"
        ), "Watch config has wrong assist config")
        #expect(watchConfig?.items == [
            .init(
                id: "script.new_script_2",
                serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
                type: .script,
                customization: .init(iconColor: "5F783D", requiresConfirmation: false)
            ),
            .init(
                id: "script.new_script_3",
                serverId: "c4f59c50552e4aebbbaffd5754aa2e9f",
                type: .script,
                customization: .init(
                    iconColor: "000000",
                    textColor: "91B860",
                    backgroundColor: "C4547A",
                    requiresConfirmation: false
                )
            ),
        ], "Watch config has wrong items config")
    }
}
