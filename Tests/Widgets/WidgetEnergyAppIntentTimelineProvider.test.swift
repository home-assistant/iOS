@testable import HomeAssistant

import Foundation
import HAKit
@testable import Shared
import SharedTesting
import Testing
import WidgetKit

/// The energy widget's entries, built from the dashboard preferences, the statistics and the live
/// power readings a stub connection answers with.
///
/// `.isolatedEnvironment`: every request is answered synchronously on the test's own task, so the
/// servers, API cache and clock the test installs reach the provider without touching the globals.
@Suite(.isolatedEnvironment)
struct WidgetEnergyAppIntentTimelineProviderTests {
    @available(iOS 17, *)
    private var provider: WidgetEnergyAppIntentTimelineProvider { .init() }

    // MARK: - Gallery

    // MARK: - Failures

    // MARK: - Statistics

    // MARK: - Early-morning fallback

    // MARK: - Pure helpers

    @available(iOS 17, *)
    @Test func costIdsComeFromTheSourceOrTheServersCostSensors() {
        let ids = WidgetEnergyAppIntentTimelineProvider.costStatIds(
            gridSources: [
                EnergySource(type: "grid", statEnergyFrom: "a", statEnergyTo: "b"),
                EnergySource(type: "grid", statEnergyFrom: "c", statCost: "c_cost", statCompensation: "c_comp"),
            ],
            gasSources: [EnergySource(type: "gas", statEnergyFrom: "g")],
            info: EnergyInfo(costSensors: ["a": "a_cost", "b": "b_comp", "g": "g_cost"], solarForecastDomains: [])
        )
        #expect(ids.cost == ["a_cost", "c_cost", "g_cost"])
        #expect(ids.compensation == ["b_comp", "c_comp"])

        let none = WidgetEnergyAppIntentTimelineProvider.costStatIds(
            gridSources: [EnergySource(type: "grid", statEnergyFrom: "a")],
            info: nil
        )
        #expect(none.cost.isEmpty)
        #expect(none.compensation.isEmpty)
        #expect(WidgetEnergyAppIntentTimelineProvider.netCost(
            cost: ["x"],
            compensation: ["y"],
            in: EnergyStatistics(byStatId: [:])
        ) == nil)
    }

    // MARK: - Helpers

    /// Registers one server whose API answers through `respond`.
    private func install(
        _ respond: @escaping WidgetStubConnection.Responder
    ) -> (Server, WidgetStubConnection) {
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: "energy-server"), serverInfo: .fake())
        Current.servers = servers
        let connection = WidgetStubConnection(respond: respond)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return (server, connection)
    }

    @available(iOS 17, *)
    private static func configuration(server: Server) -> WidgetEnergyAppIntent {
        configuration(serverId: server.identifier.rawValue)
    }

    @available(iOS 17, *)
    private static func configuration(serverId: String) -> WidgetEnergyAppIntent {
        let configuration = WidgetEnergyAppIntent()
        configuration.server = .init(identifier: .init(rawValue: serverId))
        configuration.source = .auto
        configuration.period = .today
        return configuration
    }

    private static func prefs(_ sources: [[String: Any]]) -> HAData {
        HAData(value: ["energy_sources": sources, "device_consumption": [[String: Any]]()])
    }

    private static func today(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 30, second: 0, of: Date()) ?? Date()
    }

    /// Counts the statistics requests, so the fallback query can be told apart from the first one.
    private final class StatisticsCalls: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        func next() -> Int {
            lock.lock()
            defer { lock.unlock() }
            count += 1
            return count - 1
        }
    }
}
