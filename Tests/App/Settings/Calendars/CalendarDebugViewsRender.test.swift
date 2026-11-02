import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Walks the calendar debug screens: servers, a server's calendars, and a calendar's month.
/// Shared state: the screens read `Current.servers`, the database and the calendars model, and
/// events come over a process-wide HTTP stub.
@Suite(.sharedState)
@MainActor
struct CalendarDebugViewsRenderTests {
    @Test func walksFromServersToAMonth() async throws {
        let world = try CalendarTestWorld()
        try await world.run {
            let driver = await SwiftUIScreenDriver.show(CalendarsDebugServerListView())
            defer { driver.close() }
            #expect(driver.rows.count == 1)

            await #expect(driver.push(IndexPath(item: 0, section: 0)))
            await #expect(driver.waitUntil { driver.rows.count >= 2 })
            await #expect(driver.push(driver.rows[0]))
            // The month grid, then today's events once loaded.
            await #expect(driver.waitUntil { driver.rows.count >= 4 })
            await driver.tapBarButton()
        }
    }

    @Test func showsEmptyCalendarsAndARefreshFailure() async throws {
        let world = try CalendarTestWorld()
        world.model.refreshSucceeds = false
        try await world.run {
            try await world.database.write { db in _ = try HACalendar.deleteAll(db) }
            let viewModel = CalendarsDebugListViewModel(server: world.server)
            viewModel.load()
            #expect(viewModel.calendars.isEmpty)
            await viewModel.refresh()
            #expect(viewModel.errorMessage != nil)
            #expect(world.model.refreshed == [world.server.identifier.rawValue])

            let driver = await SwiftUIScreenDriver.show(CalendarsDebugListView(server: world.server))
            defer { driver.close() }
            #expect(driver.rows.count == 1)
        }
    }

    @Test func monthShowsAFetchError() async throws {
        let world = try CalendarTestWorld()
        try await world.run(eventsStatus: 500) {
            let driver = await SwiftUIScreenDriver.show(CalendarDebugView(
                server: world.server,
                calendar: world.writable
            ))
            defer { driver.close() }
            await #expect(driver.waitUntil { driver.sectionCount >= 2 })
        }
    }

    /// Pulling either list down asks again: the calendars list refreshes the server's calendars, and
    /// a month reloads its events.
    @Test func pullingToRefreshReloadsBothLists() async throws {
        let world = try CalendarTestWorld()
        try await world.run {
            let calendars = await SwiftUIScreenDriver.show(CalendarsDebugListView(server: world.server))
            defer { calendars.close() }
            let refreshedCalendars = await calendars.pullToRefresh()
            #expect(refreshedCalendars)
            await #expect(calendars.waitUntil { world.model.refreshed == [world.server.identifier.rawValue] })

            let month = await SwiftUIScreenDriver.show(CalendarDebugView(
                server: world.server,
                calendar: world.writable
            ))
            defer { month.close() }
            await #expect(month.waitUntil { month.sectionCount >= 2 })
            let refreshedMonth = await month.pullToRefresh()
            #expect(refreshedMonth)
            await #expect(month.waitUntil { month.sectionCount >= 2 })
        }
    }
}
