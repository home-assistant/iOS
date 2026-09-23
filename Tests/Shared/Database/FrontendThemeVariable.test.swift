import GRDB
@testable import Shared
import Testing

@Suite(.serialized)
struct FrontendThemeVariableTests {
    @Test("Variables round-trip per server and appearance")
    func storesPerServerAndAppearance() throws {
        try withThemeDatabase {
            try FrontendThemeVariable.replaceAll(
                [
                    variable(serverId: "1", appearance: .light, name: "--primary-color", color: "rgb(3, 169, 244)"),
                    variable(serverId: "1", appearance: .light, name: "--spacing", value: "8px", color: nil),
                ],
                serverId: "1",
                appearance: .light
            )
            try FrontendThemeVariable.replaceAll(
                [variable(serverId: "1", appearance: .dark, name: "--primary-color", color: "rgb(68, 115, 158)")],
                serverId: "1",
                appearance: .dark
            )
            try FrontendThemeVariable.replaceAll(
                [variable(serverId: "2", appearance: .light, name: "--primary-color", color: "rgb(255, 0, 0)")],
                serverId: "2",
                appearance: .light
            )

            let lightForFirst = try FrontendThemeVariable.fetchVariables(serverId: "1", appearance: .light)
            #expect(lightForFirst.count == 2)
            #expect(lightForFirst["--primary-color"]?.colorValue == "rgb(3, 169, 244)")
            #expect(lightForFirst["--spacing"]?.value == "8px")
            // A property that is not a colour still gets a row; it just has no canonical colour.
            #expect(lightForFirst["--spacing"]?.colorValue == nil)

            let darkForFirst = try FrontendThemeVariable.fetchVariables(serverId: "1", appearance: .dark)
            #expect(darkForFirst["--primary-color"]?.colorValue == "rgb(68, 115, 158)")

            let lightForSecond = try FrontendThemeVariable.fetchVariables(serverId: "2", appearance: .light)
            #expect(lightForSecond["--primary-color"]?.colorValue == "rgb(255, 0, 0)")
        }
    }

    @Test("Re-capturing a theme drops properties it no longer declares")
    func replaceRemovesStaleProperties() throws {
        try withThemeDatabase {
            try FrontendThemeVariable.replaceAll(
                [
                    variable(serverId: "1", appearance: .light, name: "--primary-color", color: "rgb(1, 1, 1)"),
                    variable(serverId: "1", appearance: .light, name: "--gone-color", color: "rgb(2, 2, 2)"),
                ],
                serverId: "1",
                appearance: .light
            )
            try FrontendThemeVariable.replaceAll(
                [variable(serverId: "1", appearance: .light, name: "--primary-color", color: "rgb(9, 9, 9)")],
                serverId: "1",
                appearance: .light
            )

            let stored = try FrontendThemeVariable.fetchVariables(serverId: "1", appearance: .light)
            #expect(stored.count == 1)
            #expect(stored["--primary-color"]?.colorValue == "rgb(9, 9, 9)")
            #expect(stored["--gone-color"] == nil)
        }
    }

    @Test("Replacing one appearance leaves the other alone")
    func replaceIsScopedToItsAppearance() throws {
        try withThemeDatabase {
            try FrontendThemeVariable.replaceAll(
                [variable(serverId: "1", appearance: .dark, name: "--primary-color", color: "rgb(4, 4, 4)")],
                serverId: "1",
                appearance: .dark
            )
            try FrontendThemeVariable.replaceAll(
                [variable(serverId: "1", appearance: .light, name: "--primary-color", color: "rgb(5, 5, 5)")],
                serverId: "1",
                appearance: .light
            )

            let dark = try FrontendThemeVariable.fetchVariables(serverId: "1", appearance: .dark)
            #expect(dark["--primary-color"]?.colorValue == "rgb(4, 4, 4)")
        }
    }

    @Test("Deleting a server drops only its theme")
    func deleteIsScopedToItsServer() throws {
        try withThemeDatabase {
            try FrontendThemeVariable.replaceAll(
                [variable(serverId: "1", appearance: .light, name: "--primary-color", color: "rgb(1, 1, 1)")],
                serverId: "1",
                appearance: .light
            )
            try FrontendThemeVariable.replaceAll(
                [variable(serverId: "2", appearance: .light, name: "--primary-color", color: "rgb(2, 2, 2)")],
                serverId: "2",
                appearance: .light
            )

            FrontendThemeVariable.delete(serverId: "1")

            let deleted = try FrontendThemeVariable.fetchVariables(serverId: "1", appearance: .light)
            let kept = try FrontendThemeVariable.fetchVariables(serverId: "2", appearance: .light)
            #expect(deleted.isEmpty)
            #expect(kept.count == 1)
        }
    }

    @Test("A single property can be fetched by name")
    func fetchesOneProperty() throws {
        try withThemeDatabase {
            try FrontendThemeVariable.replaceAll(
                [
                    variable(
                        serverId: "1",
                        appearance: .light,
                        name: "--primary-color",
                        color: "rgb(1, 2, 3)",
                        themeName: "My Theme"
                    ),
                ],
                serverId: "1",
                appearance: .light
            )

            let stored = try FrontendThemeVariable.fetch(
                serverId: "1",
                appearance: .light,
                name: "--primary-color"
            )
            #expect(stored?.colorValue == "rgb(1, 2, 3)")
            #expect(stored?.themeName == "My Theme")

            let missing = try FrontendThemeVariable.fetch(serverId: "1", appearance: .light, name: "--nope")
            #expect(missing == nil)
        }
    }

    /// Deleting is best-effort: a server going away must not take the sign-out flow down with it.
    @Test("Deleting survives a database that has no theme table")
    func deleteSwallowsDatabaseFailures() throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }
        // No theme table, so the delete statement throws and has to be swallowed.
        let database = try DatabaseQueue(path: ":memory:")
        Current.database = { database }

        // Reaching the next line is the assertion: the failure is logged, not thrown or trapped.
        FrontendThemeVariable.delete(serverId: "1")
    }

    /// An installed table is migrated rather than recreated, which is what preserves rows across
    /// a release that adds a column.
    @Test("Creating the table twice keeps the rows that are already there")
    func createIfNeededIsIdempotent() throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }
        let database = try DatabaseQueue(path: ":memory:")
        try FrontendThemeVariableTable().createIfNeeded(database: database)
        Current.database = { database }

        try FrontendThemeVariable.replaceAll(
            [variable(serverId: "1", appearance: .light, name: "--primary-color", color: "rgb(1, 2, 3)")],
            serverId: "1",
            appearance: .light
        )
        try FrontendThemeVariableTable().createIfNeeded(database: database)

        let stored = try FrontendThemeVariable.fetchVariables(serverId: "1", appearance: .light)
        #expect(stored["--primary-color"]?.colorValue == "rgb(1, 2, 3)")
    }

    private func variable(
        serverId: String,
        appearance: FrontendThemeAppearance,
        name: String,
        value: String? = nil,
        color: String?,
        themeName: String? = nil
    ) -> FrontendThemeVariable {
        FrontendThemeVariable(
            serverId: serverId,
            appearance: appearance,
            name: name,
            value: value ?? color ?? "",
            colorValue: color,
            themeName: themeName,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func withThemeDatabase(perform work: () throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try FrontendThemeVariableTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }
        try work()
    }
}
