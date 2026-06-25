import Foundation
import GRDB
@testable import Shared
import Testing

struct KioskSettingsTests {
    @Test func roundTripsThroughDatabase() throws {
        let database = try DatabaseQueue()
        try KioskSettingsTable().createIfNeeded(database: database)

        let settings = KioskSettings(
            enabled: true,
            requireAuthentication: true,
            acceptRemoteCommands: false,
            serverId: "server-1",
            dashboard: "lovelace/home",
            keepScreenOn: true,
            removeHeaderAndSidebar: true,
            hideStatusBar: true,
            autoReload: .minutes10,
            settingsEntryPosition: .topLeading,
            screensaver: KioskScreensaverSettings(
                enabled: true,
                mode: .clock,
                clockStyle: .small,
                showDate: false,
                showSeconds: true,
                timeToStart: .minutes10,
                dimEnabled: true,
                dimLevel: 0.3,
                pixelShiftEnabled: true
            )
        )

        try database.write { db in
            try settings.insert(db, onConflict: .replace)
        }
        let loaded = try database.read { db in
            try KioskSettings.fetchOne(db)
        }

        #expect(loaded == settings)
    }

    @Test func decodesDefaultsWhenColumnsAreMissing() throws {
        // A row with only the primary key must decode with defaults (resilient decoder), so additive
        // schema migrations don't break existing installs.
        let database = try DatabaseQueue()
        try KioskSettingsTable().createIfNeeded(database: database)
        try database.write { db in
            try db.execute(
                sql: "INSERT INTO \(GRDBDatabaseTable.kioskSettings.rawValue) (id) VALUES (?)",
                arguments: [KioskSettings.kioskSettingsId]
            )
        }

        let loaded = try database.read { db in
            try KioskSettings.fetchOne(db)
        }

        #expect(loaded?.enabled == false)
        #expect(loaded?.requireAuthentication == false)
        #expect(loaded?.acceptRemoteCommands == true)
        #expect(loaded?.autoReload == .never)
        #expect(loaded?.settingsEntryPosition == .bottomTrailing)
        #expect(loaded?.screensaver == KioskScreensaverSettings())
    }

    @Test func decodesRemovedOrUnknownAutoReloadIntervalsAsNever() throws {
        // Intervals under 10 minutes were removed; a stored value that no longer resolves (the removed
        // sub-10-minute ones, or anything unrecognized) falls back to `.never` instead of failing to decode.
        let database = try DatabaseQueue()
        try KioskSettingsTable().createIfNeeded(database: database)

        func loadAutoReload(storedRawValue: String) throws -> KioskAutoReloadInterval? {
            try database.write { db in
                try db.execute(
                    sql: "INSERT OR REPLACE INTO \(GRDBDatabaseTable.kioskSettings.rawValue) (id, autoReload) "
                        + "VALUES (?, ?)",
                    arguments: [KioskSettings.kioskSettingsId, storedRawValue]
                )
            }
            return try database.read { db in try KioskSettings.fetchOne(db)?.autoReload }
        }

        let fromOneMinute = try loadAutoReload(storedRawValue: "minutes1")
        let fromFiveMinutes = try loadAutoReload(storedRawValue: "minutes5")
        let fromThirtyMinutes = try loadAutoReload(storedRawValue: "minutes30")
        let fromUnknown = try loadAutoReload(storedRawValue: "garbage")

        #expect(fromOneMinute == .never)
        #expect(fromFiveMinutes == .never)
        #expect(fromThirtyMinutes == .minutes30)
        #expect(fromUnknown == .never)
    }

    @Test func decodesDefaultsWhenScreensaverFieldsAreMissing() throws {
        let decoder = JSONDecoder()
        let data = Data(
            """
            {
              "enabled": true,
              "mode": "clock",
              "clockStyle": "small",
              "showDate": false,
              "showSeconds": true,
              "timeToStart": "minutes10",
              "dimLevel": 0.3
            }
            """.utf8
        )

        let settings = try decoder.decode(KioskScreensaverSettings.self, from: data)

        #expect(settings.dimEnabled == false)
        #expect(settings.dimLevel == 0.3)
        #expect(settings.pixelShiftEnabled == false)
    }

    @Test func enumMetadataIsComplete() {
        for mode in KioskScreensaverMode.allCases {
            #expect(!mode.title.isEmpty)
            #expect(mode.id == mode.rawValue)
        }
        for style in KioskClockStyle.allCases {
            #expect(!style.title.isEmpty)
        }
        for timeout in KioskScreensaverTimeout.allCases {
            #expect(!timeout.title.isEmpty)
            if timeout == .pushNotificationControlled {
                #expect(timeout.timeInterval == nil)
            } else {
                #expect((timeout.timeInterval ?? 0) > 0)
            }
        }
        for interval in KioskAutoReloadInterval.allCases {
            #expect(!interval.title.isEmpty)
            if interval == .never {
                #expect(interval.timeInterval == nil)
            } else {
                #expect((interval.timeInterval ?? 0) > 0)
            }
        }
        for position in KioskCornerPosition.allCases {
            #expect(!position.title.isEmpty)
        }
    }
}
