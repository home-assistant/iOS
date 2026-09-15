import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers the spoken "add this to…" command: what it writes, and the two ways it refuses.
///
/// CarPlay's availability turns on the device idiom, which the test host decides, so only the
/// destinations whose availability this can pin down are exercised here.
///
/// The availability guard sits inside each test rather than on the suite: `@Suite` cannot be applied
/// to a type marked `@available`, and the intent is iOS 17 for its destination list.
@MainActor
@Suite(.serialized)
struct AddEntityToAppIntentTests {
    @Test("Adding to the watch stores the entity")
    func addsToWatch() async throws {
        guard #available(iOS 17.0, *) else { return }
        try await withConfigDatabase(isCatalyst: false) {
            let intent = AddEntityToAppIntent()
            intent.entity = Self.entity()
            intent.destination = .appleWatch

            _ = try await intent.perform()

            let stored = try WatchConfig.config()
            let items = try #require(stored?.items)
            #expect(items.map(\.id) == ["light.kitchen"])
        }
    }

    @Test("Adding to the Mac toolbar stores the entity on a Mac")
    func addsToMacToolbarOnCatalyst() async throws {
        guard #available(iOS 17.0, *) else { return }
        try await withConfigDatabase(isCatalyst: true) {
            let intent = AddEntityToAppIntent()
            intent.entity = Self.entity()
            intent.destination = .macToolbar

            _ = try await intent.perform()

            let stored = try MacToolbarConfig.config()
            let items = try #require(stored?.items)
            #expect(items.map(\.id) == ["light.kitchen"])
        }
    }

    /// Running it twice is not an error — the second run says the entity is already there rather than
    /// adding a duplicate row.
    @Test("Adding an entity that is already there reports it instead of adding it twice")
    func reportsAnEntityThatIsAlreadyThere() async throws {
        guard #available(iOS 17.0, *) else { return }
        try await withConfigDatabase(isCatalyst: false) {
            let intent = AddEntityToAppIntent()
            intent.entity = Self.entity()
            intent.destination = .appleWatch

            _ = try await intent.perform()
            _ = try await intent.perform()

            let stored = try WatchConfig.config()
            let items = try #require(stored?.items)
            #expect(items.count == 1)
        }
    }

    /// A camera has no row on the watch's home screen, so asking for one has to fail rather than
    /// write an item the watch would then skip.
    @Test("A domain the destination cannot show is refused, and nothing is written")
    func refusesUnsupportedDomain() async throws {
        guard #available(iOS 17.0, *) else { return }
        try await withConfigDatabase(isCatalyst: false) {
            let intent = AddEntityToAppIntent()
            intent.entity = Self.entity(entityId: "camera.porch", displayString: "Porch")
            intent.destination = .appleWatch

            await #expect(throws: ShortcutAppIntentError.self) {
                _ = try await intent.perform()
            }
            let stored = try WatchConfig.config()
            #expect(stored == nil)
        }
    }

    @Test("A destination this device does not have is refused, and nothing is written")
    func refusesUnavailableDestination() async throws {
        guard #available(iOS 17.0, *) else { return }
        try await withConfigDatabase(isCatalyst: false) {
            let intent = AddEntityToAppIntent()
            intent.entity = Self.entity()
            intent.destination = .macToolbar

            await #expect(throws: ShortcutAppIntentError.self) {
                _ = try await intent.perform()
            }
            let stored = try MacToolbarConfig.config()
            #expect(stored == nil)
        }
    }

    /// Reading the summary runs the builder that lays the command out in the Shortcuts editor, and
    /// reading the title and description builds the strings it is listed under. Nothing else in these
    /// tests reaches them, and a summary naming a parameter the intent no longer has stops the editor
    /// from drawing it.
    @Test("The intent describes itself for the Shortcuts editor")
    func theIntentDescribesItself() {
        guard #available(iOS 17.0, *) else { return }
        #expect(!String(describing: AddEntityToAppIntent.parameterSummary).isEmpty)
        #expect(!String(describing: AddEntityToAppIntent.title).isEmpty)
        #expect(!String(describing: AddEntityToAppIntent.description).isEmpty)
    }

    private static func entity(
        entityId: String = "light.kitchen",
        displayString: String = "Kitchen"
    ) -> HAAppEntityAppIntentEntity {
        HAAppEntityAppIntentEntity(
            id: ServerEntity.uniqueId(serverId: "1", entityId: entityId),
            entityId: entityId,
            serverId: "1",
            serverName: "Home",
            displayString: displayString,
            iconName: "mdi:lightbulb"
        )
    }

    private func withConfigDatabase(
        isCatalyst: Bool,
        perform work: () async throws -> Void
    ) async throws {
        let previousDatabase = Current.database
        let previousIsCatalyst = Current.isCatalyst
        let database = try DatabaseQueue(path: ":memory:")

        try WatchConfigTable().createIfNeeded(database: database)
        try MacToolbarConfigTable().createIfNeeded(database: database)
        try HAppEntityTable().createIfNeeded(database: database)
        Current.database = { database }
        Current.isCatalyst = isCatalyst

        defer {
            Current.database = previousDatabase
            Current.isCatalyst = previousIsCatalyst
        }

        try await work()
    }
}
