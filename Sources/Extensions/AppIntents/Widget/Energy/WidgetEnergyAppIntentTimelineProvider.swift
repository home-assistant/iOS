import AppIntents
import HAKit
import Shared
import WidgetKit

@available(iOS 17, *)
struct WidgetEnergyAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetEnergyEntry
    typealias Intent = WidgetEnergyAppIntent

    static let expiration: Measurement<UnitDuration> = .init(value: 15, unit: .minutes)

    func placeholder(in context: Context) -> WidgetEnergyEntry {
        WidgetEnergyEntry(
            isConfigured: true,
            gridConsumed: 6.2,
            gridReturned: 10.5,
            solarGenerated: 12.4,
            cost: -0.49,
            currencyCode: "EUR",
            livePowerGrid: -250,
            livePowerSolar: 250,
            chartPoints: Self.placeholderChart()
        )
    }

    func snapshot(for configuration: WidgetEnergyAppIntent, in context: Context) async -> WidgetEnergyEntry {
        // The widget gallery/picker shows a snapshot with `isPreview` set — serve mocked data there
        // instead of hitting the server.
        if context.isPreview {
            return placeholder(in: context)
        }
        return await (try? entry(for: configuration, in: context)) ?? placeholder(in: context)
    }

    func timeline(for configuration: WidgetEnergyAppIntent, in context: Context) async -> Timeline<Entry> {
        if context.isPreview {
            return .init(entries: [placeholder(in: context)], policy: .never)
        }
        let entry: WidgetEnergyEntry
        do {
            entry = try await self.entry(for: configuration, in: context)
        } catch {
            Current.Log.error("Failed to build energy widget timeline: \(error)")
            entry = WidgetEnergyEntry(period: configuration.period, isConfigured: false, loadFailed: true)
        }
        return .init(
            entries: [entry],
            policy: .after(Current.date().addingTimeInterval(Self.expiration.converted(to: .seconds).value))
        )
    }

    // MARK: - Entry building

    private func entry(for configuration: WidgetEnergyAppIntent, in context: Context) async throws -> Entry {
        guard let server = configuration.server.getServer() ?? Current.servers.all.first,
              let connection = Current.api(for: server)?.connection else {
            Current.Log.error("Energy widget: no API for server (selected id: \(configuration.server.id))")
            return WidgetEnergyEntry(period: configuration.period, isConfigured: false, loadFailed: true)
        }

        // Tapping the widget opens the server's energy dashboard.
        let widgetURL = AppConstants.openPageDeeplinkURL(
            path: "energy",
            serverId: server.identifier.rawValue
        ) ?? AppConstants.deeplinkURL

        guard let prefs: EnergyPreferences = await send(.energyGetPrefs(), on: connection) else {
            return WidgetEnergyEntry(
                period: configuration.period,
                source: configuration.source,
                serverName: server.info.name,
                widgetURL: widgetURL,
                isConfigured: false,
                loadFailed: true
            )
        }
        guard !prefs.energySources.isEmpty else {
            return WidgetEnergyEntry(
                period: configuration.period,
                source: configuration.source,
                serverName: server.info.name,
                widgetURL: widgetURL,
                isConfigured: false
            )
        }

        let info: EnergyInfo? = await send(.energyInfo(), on: connection)
        let gridSources = prefs.energySources.filter { $0.type == "grid" }
        let solarSources = prefs.energySources.filter { $0.type == "solar" }
        let ids = StatisticIds(
            gridImport: gridSources.compactMap(\.statEnergyFrom),
            gridExport: gridSources.compactMap(\.statEnergyTo),
            solar: solarSources.compactMap(\.statEnergyFrom),
            cost: costStatIds(gridSources: gridSources, info: info)
        )

        var entry = await entryWithStatistics(
            for: configuration.period,
            ids: ids,
            on: connection,
            base: WidgetEnergyEntry(
                period: configuration.period,
                source: configuration.source,
                serverName: server.info.name,
                widgetURL: widgetURL,
                isConfigured: true
            )
        )

        // Early in the morning "today" is usually empty only because the day just began, so summarise
        // the day before rather than showing a blank card until the first statistics land. A failed
        // load is not an empty day, so it never falls back — it reports the failure instead.
        if !entry.hasStatistics, !entry.loadFailed,
           let fallback = configuration.period.emptyDataFallback(now: Current.date()) {
            var fallbackEntry = entry
            fallbackEntry.period = fallback
            fallbackEntry = await entryWithStatistics(for: fallback, ids: ids, on: connection, base: fallbackEntry)
            if fallbackEntry.hasStatistics {
                entry = fallbackEntry
            }
        }

        entry.currencyCode = entry.cost == nil ? nil : await fetchCurrency(on: connection)

        // Live power only matters for the compact layouts; skip the extra REST calls otherwise.
        if WidgetEnergySupportedFamilies.livePowerFamilies.contains(context.family) {
            entry.livePowerSolar = await solarLivePower(sources: solarSources, server: server)
            entry.livePowerGrid = await gridLivePower(sources: gridSources, server: server)
        }

        return entry
    }

    // MARK: - Statistics helpers

    /// The statistic ids the energy dashboard preferences resolve to, grouped by the series each one
    /// feeds. They don't depend on the period, so a fallback query reuses them as they are.
    private struct StatisticIds {
        let gridImport: [String]
        let gridExport: [String]
        let solar: [String]
        let cost: [String]

        var all: [String] { Array(Set(gridImport + gridExport + solar + cost)) }
    }

    /// Queries the statistics for one window and returns the entry filled with its totals and chart.
    /// A failed request comes back flagged as such, so the widget can offer a retry instead of
    /// passing the outage off as a period with nothing in it.
    private func entryWithStatistics(
        for period: WidgetEnergyPeriod,
        ids: StatisticIds,
        on connection: HAConnection,
        base: WidgetEnergyEntry
    ) async -> WidgetEnergyEntry {
        let statIds = ids.all
        guard !statIds.isEmpty else { return base }
        let range = period.dateRange(now: Current.date())
        guard let stats: EnergyStatistics = await send(
            .statisticsDuringPeriod(
                startTime: range.start,
                endTime: range.end,
                statisticIds: statIds,
                period: period.statisticsPeriod
            ),
            on: connection
        ) else {
            var entry = base
            entry.loadFailed = true
            return entry
        }

        var entry = base
        entry.gridConsumed = sumTotals(ids: ids.gridImport, in: stats)
        entry.gridReturned = sumTotals(ids: ids.gridExport, in: stats)
        entry.solarGenerated = sumTotals(ids: ids.solar, in: stats)
        entry.cost = sumTotals(ids: ids.cost, in: stats)
        entry.chartPoints = chartPoints(importIds: ids.gridImport, solarIds: ids.solar, in: stats)
        return entry
    }

    private func costStatIds(gridSources: [EnergySource], info: EnergyInfo?) -> [String] {
        var ids: [String] = []
        for source in gridSources {
            if let cost = source.statCost ?? source.statEnergyFrom.flatMap({ info?.costSensors[$0] }) {
                ids.append(cost)
            }
            if let compensation = source.statCompensation ?? source.statEnergyTo.flatMap({ info?.costSensors[$0] }) {
                ids.append(compensation)
            }
        }
        return ids
    }

    private func sumTotals(ids: [String], in stats: EnergyStatistics) -> Double? {
        let present = ids.filter { stats.byStatId[$0] != nil }
        guard !present.isEmpty else { return nil }
        return present.reduce(0) { $0 + (stats.totalChange(for: $1) ?? 0) }
    }

    /// Builds the chart series: grid consumption and solar generation, both clamped to ≥ 0 and
    /// stacked as positive bars, keyed per statistics bucket.
    private func chartPoints(
        importIds: [String],
        solarIds: [String],
        in stats: EnergyStatistics
    ) -> [WidgetEnergyEntry.ChartPoint] {
        var gridByStart: [Date: Double] = [:]
        var solarByStart: [Date: Double] = [:]
        for id in importIds {
            for bucket in stats.byStatId[id] ?? [] {
                gridByStart[bucket.start, default: 0] += (bucket.change ?? 0)
            }
        }
        for id in solarIds {
            for bucket in stats.byStatId[id] ?? [] {
                solarByStart[bucket.start, default: 0] += (bucket.change ?? 0)
            }
        }
        let dates = Set(gridByStart.keys).union(solarByStart.keys).sorted()
        return dates.map { date in
            WidgetEnergyEntry.ChartPoint(
                date: date,
                grid: max(gridByStart[date] ?? 0, 0),
                solar: max(solarByStart[date] ?? 0, 0)
            )
        }
    }

    // MARK: - Live power

    private func solarLivePower(sources: [EnergySource], server: Server) async -> Double? {
        var total: Double?
        for source in sources {
            guard let rate = source.statRate, let value = await powerState(entityId: rate, server: server) else {
                continue
            }
            if value > 0 { total = (total ?? 0) + value }
        }
        return total
    }

    private func gridLivePower(sources: [EnergySource], server: Server) async -> Double? {
        var total: Double?
        for source in sources {
            if let config = source.powerConfig {
                var value = 0.0
                if let from = config.statRateFrom, let power = await powerState(entityId: from, server: server) {
                    value += power
                }
                if let to = config.statRateTo, let power = await powerState(entityId: to, server: server) {
                    value -= power
                }
                if let rate = config.statRate, let power = await powerState(entityId: rate, server: server) {
                    value += config.inverted ? -power : power
                }
                total = (total ?? 0) + value
            } else if let rate = source.statRate, let power = await powerState(entityId: rate, server: server) {
                total = (total ?? 0) + power
            }
        }
        return total
    }

    /// Reads an entity's state as watts, normalising kW/MW to W.
    private func powerState(entityId: String, server: Server) async -> Double? {
        guard let connection = Current.api(for: server)?.connection else { return nil }
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<
            Result<HAData, HAError>,
            Never
        >) in
            connection.send(.init(type: .rest(.get, "states/\(entityId)"), shouldRetry: true)) { result in
                continuation.resume(returning: result)
            }
        }
        guard let data = try? result.get(),
              case let .dictionary(dictionary) = data,
              let stateString = dictionary["state"] as? String,
              let value = Double(stateString) else {
            return nil
        }
        let unit = (dictionary["attributes"] as? [String: Any])?["unit_of_measurement"] as? String
        switch unit?.lowercased() {
        case "kw": return value * 1000
        case "mw": return value * 1_000_000
        default: return value
        }
    }

    // MARK: - Config

    private func fetchCurrency(on connection: HAConnection) async -> String? {
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<
            Result<HAData, HAError>,
            Never
        >) in
            connection.send(.init(type: .rest(.get, "config"), shouldRetry: true)) { result in
                continuation.resume(returning: result)
            }
        }
        guard let data = try? result.get() else { return nil }
        return data.decode("currency", fallback: nil)
    }

    private func send<T>(_ request: HATypedRequest<T>, on connection: HAConnection) async -> T? {
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            connection.send(request) { result in
                switch result {
                case let .success(value):
                    continuation.resume(returning: value)
                case let .failure(error):
                    Current.Log.error("Energy widget request failed: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func placeholderChart() -> [WidgetEnergyEntry.ChartPoint] {
        let dayStart = Calendar.current.startOfDay(for: Current.date())
        return (0 ..< 24).map { hour in
            // Grid consumption peaks morning and evening; solar peaks midday.
            let h = Double(hour)
            let grid = 0.25 + 0.8 * exp(-pow(h - 7, 2) / 4) + 1.0 * exp(-pow(h - 20, 2) / 6)
            let solar = h >= 6 && h <= 18 ? 1.6 * sin((h - 6) / 12 * .pi) : 0
            return WidgetEnergyEntry.ChartPoint(
                date: dayStart.addingTimeInterval(h * 3600),
                grid: grid,
                solar: solar
            )
        }
    }
}
