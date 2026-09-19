import Foundation
import HAKit
import HAWatchComplications
import Shared
import WidgetKit

/// Reads every server's energy dashboard and leaves one ready-to-draw payload per server in the
/// shared app group, which is what makes the watch offer an energy complication per server.
///
/// It lives in the app rather than in the widget extension because it has to: energy preferences and
/// long-term statistics are websocket commands, and the extension links nothing that speaks them.
/// So this runs alongside the entity complications' refresh — on launch, on a pushed mirror, and on
/// the background refresh — and the face renders whatever it last managed to write.
///
/// The window is always today, the same default the phone's Energy widget starts on, with the same
/// early-morning fallback: before 5am "today" is usually empty only because the day just began, so
/// it summarises yesterday instead of showing a blank chart over breakfast.
enum WatchEnergyComplicationRefresher {
    /// Identity of the server set the picker was last told about, so `recommendations()` is only
    /// re-queried when a server was actually added or removed.
    private static let serversIdentityKey = "watchEnergyComplicationServersIdentity"

    /// Hour before which today has too little behind it to summarise on its own.
    private static let earlyMorningHour = 5

    /// Rebuilds one payload per server, in the app's own order — which is the order the picker then
    /// lists the complications in.
    ///
    /// Servers are read one after another, like the credentials write alongside it: a watch has one
    /// server far more often than two, and the requests all share a single websocket connection per
    /// server anyway, so there is nothing for concurrency to overlap.
    static func refresh() async {
        let defaults = UserDefaults(suiteName: AppConstants.AppGroupID)
        let previous = EnergyComplicationSnapshot.read(from: defaults)
        var snapshots: [EnergyComplicationSnapshot] = []
        for server in Current.servers.all {
            let built = await snapshot(for: server)
            snapshots.append(built)
        }
        // A pass that was cancelled partway would otherwise drop the servers it never reached from
        // the picker; leave the store as it was and let the next refresh rebuild it.
        guard !Task.isCancelled else { return }
        apply(snapshots, previous: previous, defaults: defaults)
    }

    // MARK: - Persistence

    /// Writes the payloads and asks WidgetKit for what actually changed — nothing when the content
    /// is identical, which is the common case between two refreshes of a quiet dashboard.
    private static func apply(
        _ snapshots: [EnergyComplicationSnapshot],
        previous: [EnergyComplicationSnapshot],
        defaults: UserDefaults?
    ) {
        guard snapshots != previous else { return }
        EnergyComplicationSnapshot.write(snapshots, to: defaults)
        // Every kind rather than this one: the widget registers its kind from the extension's own
        // bundle identifier, which can differ from anything this process can derive (debug builds
        // suffix it), and a mismatched `ofKind:` is a silent no-op.
        WidgetCenter.shared.reloadAllTimelines()

        // The picker's list only changes when a server is added or removed, so re-querying it on
        // every value change would just double the extension launches.
        let identity = snapshots.map(\.serverId).sorted().joined(separator: "|")
        if defaults?.string(forKey: serversIdentityKey) != identity {
            WidgetCenter.shared.invalidateConfigurationRecommendations()
            defaults?.set(identity, forKey: serversIdentityKey)
        }
    }

    // MARK: - Per server

    private static func snapshot(for server: Server) async -> EnergyComplicationSnapshot {
        // Without an active URL there is nowhere to load from, and no request is worth sending: the
        // fix is in the server's URL configuration rather than in a retry.
        guard await server.activeURL() != nil, let connection = Current.api(for: server)?.connection else {
            return .init(for: server, message: L10n.Widgets.Energy.noConnection)
        }
        guard let prefs: EnergyPreferences = await send(.energyGetPrefs(), on: connection) else {
            return .init(for: server, message: L10n.Widgets.Energy.noData)
        }
        let series = EnergyStatisticsSummary.Series(sources: prefs.energySources)
        let gasIds = prefs.energySources.filter { $0.type == "gas" }.compactMap(\.statEnergyFrom)
        let statIds = series.all + gasIds
        guard !statIds.isEmpty else {
            return .init(for: server, message: L10n.Widgets.Energy.notConfigured)
        }

        let gasUnit = await resolveGasUnit(for: gasIds, on: connection)
        guard var summary = await loadSummary(
            in: todayWindow(now: Current.date()),
            statIds: statIds,
            series: series,
            gasIds: gasIds,
            gasUnit: gasUnit,
            on: connection
        ) else {
            // The request itself failed. That is not an empty day, so it is reported as a failure
            // rather than being passed off as a period with nothing in it.
            return .init(for: server, message: L10n.Widgets.Energy.noData)
        }

        // A day that has only just begun otherwise reads as an outage over breakfast.
        if summary.isEmpty, let earlier = fallbackWindow(now: Current.date()) {
            summary = await loadSummary(
                in: earlier,
                statIds: statIds,
                series: series,
                gasIds: gasIds,
                gasUnit: gasUnit,
                on: connection
            ) ?? summary
        }
        guard !summary.isEmpty else {
            return .init(for: server, message: L10n.Widgets.Energy.noData)
        }
        return .init(for: server, stats: summary.figures, bars: summary.bars)
    }

    /// One window's worth of figures and bars, or nil when the statistics request itself failed —
    /// which is the distinction that stops an outage being reported as a day with nothing in it.
    private static func loadSummary(
        in window: (start: Date, end: Date),
        statIds: [String],
        series: EnergyStatisticsSummary.Series,
        gasIds: [String],
        gasUnit: GasUnit?,
        on connection: HAConnection
    ) async -> Summary? {
        guard let response: EnergyStatistics = await send(
            .statisticsDuringPeriod(
                startTime: window.start,
                endTime: window.end,
                statisticIds: statIds,
                period: "hour",
                volumeUnit: gasUnit?.volume
            ),
            on: connection
        ) else {
            return nil
        }

        let bars = EnergyStatisticsSummary.chartPoints(for: series, in: response).map { point in
            EnergyComplicationChartBar(
                date: point.date,
                solarUsed: point.solarUsed,
                batteryUsed: point.batteryUsed,
                gridUsed: point.gridUsed,
                batteryCharged: point.batteryCharged,
                gridReturned: point.gridReturned
            )
        }
        return Summary(
            figures: figures(from: response, series: series, gasIds: gasIds, gasUnit: gasUnit?.display),
            bars: bars
        )
    }

    /// What one window came back with.
    private struct Summary {
        let figures: [EnergyComplicationStat]
        let bars: [EnergyComplicationChartBar]

        /// The server answered, but with nothing in the window — which is what the early-morning
        /// fallback exists for.
        var isEmpty: Bool { figures.isEmpty && bars.allSatisfy(\.isEmpty) }
    }

    /// How a gas figure is read and labelled — see ``resolveGasUnit(for:on:)``.
    private struct GasUnit {
        let display: String
        /// Nil when the meter reports energy and the request's existing kWh conversion covers it.
        let volume: String?
    }

    /// The headline figures, in the widget's own order — grid, solar, battery, gas — skipping any
    /// series the server doesn't report.
    ///
    /// The grid leads because it is the one series every energy dashboard has. Its figure is the
    /// period's net, counted the way the dashboard's "Electricity total" is; the battery's is its
    /// net the other way round, discharge positive, because a battery is read as something that
    /// supplies the home rather than as a bill.
    private static func figures(
        from response: EnergyStatistics,
        series: EnergyStatisticsSummary.Series,
        gasIds: [String],
        gasUnit: String?
    ) -> [EnergyComplicationStat] {
        func total(_ ids: [String]) -> Double? { EnergyStatisticsSummary.total(of: ids, in: response) }
        let consumed = total(series.gridImport)
        let returned = total(series.gridExport)
        let charged = total(series.batteryCharge)
        let discharged = total(series.batteryDischarge)

        var figures: [EnergyComplicationStat] = []
        if consumed != nil || returned != nil {
            figures.append(.energy(.grid, kWh: (consumed ?? 0) - (returned ?? 0)))
        }
        if let solar = total(series.solar) {
            figures.append(.energy(.solar, kWh: solar))
        }
        if charged != nil || discharged != nil {
            figures.append(.energy(.batteryOut, kWh: (discharged ?? 0) - (charged ?? 0)))
        }
        if let gas = total(gasIds) {
            figures.append(.init(
                series: .gas,
                value: EnergyComplicationStat.quantity(gas),
                // Volume as often as energy, so the unit comes from the recorder rather than here.
                unit: gasUnit ?? EnergyComplicationStat.energyUnit
            ))
        }
        return figures
    }

    // MARK: - Windows

    private static func todayWindow(now: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        (calendar.startOfDay(for: now), now)
    }

    /// Yesterday, but only in the small hours — at any other time an empty day is the honest answer.
    private static func fallbackWindow(
        now: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        guard calendar.component(.hour, from: now) < earlyMorningHour else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        return (startOfYesterday, startOfToday)
    }

    // MARK: - Gas

    /// How to read the home's gas meter: the unit to ask the recorder for, and the unit to label the
    /// figure with. Nil when no gas source is configured, which is the common case.
    ///
    /// Gas is metered either by volume or by energy content, and only the recorder's metadata says
    /// which — exactly as `getEnergyGasUnitClass` resolves it in the frontend. Where the phone's
    /// widget also asks the server which measurement system the home uses, this settles for the
    /// recorder's own display unit and falls back to m³: that is one fewer round trip inside a
    /// background refresh, and it only differs for a meter that reports no unit at all.
    private static func resolveGasUnit(for statIds: [String], on connection: HAConnection) async -> GasUnit? {
        guard !statIds.isEmpty else { return nil }
        let metadata: EnergyStatisticsMetadata? = await send(
            .statisticsMetadata(statisticIds: statIds),
            on: connection
        )
        if metadata?.commonUnitClass(of: statIds) == "energy" {
            // The statistics request already asks for kWh, so there is nothing to convert.
            return GasUnit(display: EnergyComplicationStat.energyUnit, volume: nil)
        }
        let reported = metadata?.commonDisplayUnit(of: statIds)
        let unit = reported.flatMap { volumeUnits.contains($0) ? $0 : nil } ?? "m³"
        return GasUnit(display: unit, volume: unit)
    }

    /// The volume units the recorder converts between, from `VOLUME_UNITS` in the frontend's
    /// `src/data/recorder.ts`. Asking for anything else fails the whole statistics request.
    private static let volumeUnits: Set<String> = ["L", "gal", "ft³", "m³", "CCF", "MCF"]

    // MARK: - Transport

    private static func send<T>(_ request: HATypedRequest<T>, on connection: HAConnection) async -> T? {
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            connection.send(request) { result in
                switch result {
                case let .success(value):
                    continuation.resume(returning: value)
                case let .failure(error):
                    Current.Log.error("Watch energy complication request failed: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
