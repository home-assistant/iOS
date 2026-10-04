import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// The smaller pickers and intents behind widget configuration: domains, calendars, attributes,
/// and the parameter summaries the widget editor draws.
///
/// Serialized because the calendar tests swap the database and the servers in `Current`.
@Suite(.serialized)
struct WidgetConfigurationQueriesTests {
    @available(iOS 17, *)
    @Test func domainQueryResolvesKnownAndUnknownDomains() async throws {
        let query = WidgetDomainAppEntityQuery()

        let entities = try await query.entities(for: ["light", "made_up_domain"])

        #expect(entities.map(\.id) == ["light", "made_up_domain"])
        #expect(entities.first?.name == Domain.light.name)
        // A domain the app does not model keeps its identifier as its name.
        #expect(entities.last?.name == "made_up_domain")
        _ = entities.first?.displayRepresentation

        _ = try await query.suggestedEntities()
        _ = try await query.entities(matching: "light")
    }

    @available(iOS 17, *)
    @Test func calendarQueryResolvesStoredCalendars() async throws {
        try await withCalendars {
            let query = WidgetCalendarAppEntityQuery()

            let entities = try await query.entities(for: ["s1-calendar.family", "s1-calendar.gone"])

            #expect(entities.map(\.entityId) == ["calendar.family"])
            let family = try #require(entities.first)
            #expect(family.name == "Family")
            #expect(family.serverId == "s1")
            #expect(family.id == "s1-calendar.family")
            _ = family.displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "work")
            _ = try await query.entities(matching: "calendar.family")
        }
    }

    @available(iOS 17, *)
    @Test func calendarEntityMirrorsTheStoredCalendar() {
        let calendar = HACalendar(
            id: "s1-calendar.family",
            serverId: "s1",
            entityId: "calendar.family",
            name: "Family",
            backgroundColor: "#FF0000",
            supportedFeatures: 0,
            sortOrder: 0
        )

        let entity = WidgetCalendarAppEntity(calendar: calendar)

        #expect(entity.id == calendar.id)
        #expect(entity.entityId == "calendar.family")
        #expect(entity.serverId == "s1")
        #expect(entity.name == "Family")
    }

    @available(iOS 17, *)
    @Test func detailsAttributeQueryMapsIdentifiers() async throws {
        let entities = try await WidgetDetailsAttributeAppEntityQuery().entities(for: ["humidity", "temperature"])

        #expect(entities.map(\.id) == ["humidity", "temperature"])
        _ = entities.first?.displayRepresentation
    }

    @available(iOS 17, *)
    @Test func widgetIntentsBuildTheirParameterSummaries() {
        #expect(!String(describing: WidgetDetailsAppIntent.parameterSummary).isEmpty)
        #expect(!String(describing: WidgetScriptsAppIntent.parameterSummary).isEmpty)
        #expect(!String(describing: WidgetCommonlyUsedEntitiesAppIntent.parameterSummary).isEmpty)
    }

    /// A script widget with nothing picked has nothing to run.
    @available(iOS 17, *)
    @Test func scriptsIntentWithoutScriptsRunsNothing() async throws {
        let intent = WidgetScriptsAppIntent()

        _ = try await intent.perform()

        #expect(intent.scripts == nil)
        #expect(intent.showConfirmationDialog)
    }

    @available(iOS 17, *)
    @Test func commonlyUsedEntitiesDomainFilterFollowsThePickers() {
        let intent = WidgetCommonlyUsedEntitiesAppIntent()
        intent.includedDomains = [WidgetDomainAppEntity(domain: .light), WidgetDomainAppEntity(domain: .switch)]
        intent.excludedDomains = [WidgetDomainAppEntity(domain: .switch)]

        let filter = intent.domainFilter

        #expect(filter.filter(entityIds: ["light.kitchen", "switch.porch", "sensor.power"]) == ["light.kitchen"])
        #expect(WidgetCommonlyUsedEntitiesConstants.expiration.converted(to: .seconds).value == 15 * 60)
    }

    // MARK: - Helpers

    private func withCalendars(_ body: () async throws -> Void) async throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let database = try DatabaseQueue(path: ":memory:")
        try HACalendarTable().createIfNeeded(database: database)
        Current.database = { database }

        let servers = FakeServerManager()
        servers.add(identifier: .init(rawValue: "s1"), serverInfo: .fake())
        Current.servers = servers

        try await database.write { db in
            try HACalendar(
                id: "s1-calendar.family",
                serverId: "s1",
                entityId: "calendar.family",
                name: "Family",
                backgroundColor: "#FF0000",
                supportedFeatures: 0,
                sortOrder: 0
            ).insert(db)
            try HACalendar(
                id: "s1-calendar.work",
                serverId: "s1",
                entityId: "calendar.work",
                name: "Work",
                backgroundColor: "#00FF00",
                supportedFeatures: 0,
                sortOrder: 1
            ).insert(db)
            // A calendar whose server is gone still gets a section, named after its identifier.
            try HACalendar(
                id: "s2-calendar.old",
                serverId: "s2",
                entityId: "calendar.old",
                name: "Old",
                backgroundColor: "#0000FF",
                supportedFeatures: 0,
                sortOrder: 0
            ).insert(db)
        }

        try await body()
    }
}
