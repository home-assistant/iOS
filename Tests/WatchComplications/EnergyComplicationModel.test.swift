import Foundation
import HAWatchComplications
import Testing
import UIKit

/// The energy complication's data model: the payload the watch app leaves in the app group, the
/// figures it carries, and the buckets its chart is drawn from.
///
/// On iOS rather than on the watch, even though the complication only ever renders on a watch: the
/// types are platform-agnostic, and this is the test target the coverage report is built from.
struct EnergyComplicationModelTests {
    private static let date = Date(timeIntervalSince1970: 1_700_000_000)

    private static func snapshot(
        serverId: String = "server-1",
        serverName: String = "Home",
        stats: [EnergyComplicationStat] = [],
        bars: [EnergyComplicationChartBar] = [],
        message: String? = nil
    ) -> EnergyComplicationSnapshot {
        .init(
            serverId: serverId,
            serverName: serverName,
            date: date,
            stats: stats,
            bars: bars,
            message: message
        )
    }

    // MARK: - Snapshot

    /// The watch app and the widget extension never share a type instance, only this JSON, so a
    /// round trip is the only thing standing between a rename and a face that silently stops
    /// updating.
    @Test func survivesTheTripThroughTheAppGroup() throws {
        let original = [
            Self.snapshot(stats: EnergyComplicationSampleData.stats, bars: EnergyComplicationSampleData.bars),
            Self.snapshot(serverId: "server-2", serverName: "Cabin", message: "No energy data"),
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([EnergyComplicationSnapshot].self, from: data)
        #expect(decoded == original)
    }

    @Test func writesAndReadsBackFromDefaults() throws {
        let suite = "EnergyComplicationModelTests"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let snapshots = [Self.snapshot(stats: EnergyComplicationSampleData.stats)]

        EnergyComplicationSnapshot.write(snapshots, to: defaults)

        #expect(EnergyComplicationSnapshot.read(from: defaults) == snapshots)
        defaults.removePersistentDomain(forName: suite)
    }

    /// Neither half may trap on a store that isn't there: the widget extension reads before the
    /// watch app has ever written, and an app group that can't be opened is a configuration
    /// problem, not a reason to take the complication down.
    @Test func toleratesAStoreItCannotOpen() {
        #expect(EnergyComplicationSnapshot.read(from: nil).isEmpty)
        EnergyComplicationSnapshot.write([Self.snapshot()], to: nil)
    }

    @Test func readsNothingFromAStoreHoldingSomethingElse() throws {
        let suite = "EnergyComplicationModelTests.corrupt"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(Data("not a snapshot".utf8), forKey: EnergyComplicationSnapshot.defaultsKey)

        #expect(EnergyComplicationSnapshot.read(from: defaults).isEmpty)
        defaults.removePersistentDomain(forName: suite)
    }

    /// A server whose dashboard couldn't be read still belongs in the store: it is what keeps that
    /// server's complication in the picker instead of making it vanish until the next refresh.
    @Test func aMessageOnlySnapshotHasNoContent() {
        #expect(Self.snapshot(message: "No energy data").hasContent == false)
        #expect(Self.snapshot(stats: EnergyComplicationSampleData.stats).hasContent)
        #expect(Self.snapshot().id == "server-1")
    }

    /// Early in the day the server answers with buckets that are all zero. That is a period with
    /// nothing in it, not a chart.
    @Test func barsWithNothingInThemCountAsEmpty() {
        let bar = EnergyComplicationChartBar(date: Self.date, solarUsed: 0, gridUsed: 0)
        #expect(bar.isEmpty)
        #expect(bar.id == Self.date)
        #expect(Self.snapshot(bars: [bar]).hasContent == false)
        #expect(Self.snapshot(bars: EnergyComplicationSampleData.bars).hasContent)
    }

    /// Each flow on its own is enough to make a bucket worth drawing — including the two that hang
    /// below the axis, which a check written against the consumption side alone would call empty.
    @Test func anyFlowMakesABucketWorthDrawing() {
        let flows: [(String, EnergyComplicationChartBar)] = [
            ("solar", .init(date: Self.date, solarUsed: 0.4, gridUsed: 0)),
            ("battery out", .init(date: Self.date, solarUsed: 0, batteryUsed: 0.4, gridUsed: 0)),
            ("grid", .init(date: Self.date, solarUsed: 0, gridUsed: 0.4)),
            ("battery in", .init(date: Self.date, solarUsed: 0, gridUsed: 0, batteryCharged: 0.4)),
            ("grid return", .init(date: Self.date, solarUsed: 0, gridUsed: 0, gridReturned: 0.4)),
        ]
        for (name, bar) in flows {
            #expect(bar.isEmpty == false, "\(name) should make the bucket worth drawing")
        }
    }

    // MARK: - Render model

    /// The name is the caller's call, because only the caller can see how many servers there are.
    @Test func theServerNameIsOnlyCarriedWhenItIsWorthALine() {
        let snapshot = Self.snapshot(stats: EnergyComplicationSampleData.stats)
        #expect(EnergyComplicationRenderModel(snapshot: snapshot, showsServerName: true).serverName == "Home")
        #expect(EnergyComplicationRenderModel(snapshot: snapshot, showsServerName: false).serverName == nil)
    }

    @Test func theRenderModelCarriesTheRestOfTheSnapshotThrough() {
        let snapshot = Self.snapshot(
            stats: EnergyComplicationSampleData.stats,
            bars: EnergyComplicationSampleData.bars,
            message: "No energy data"
        )
        let model = EnergyComplicationRenderModel(snapshot: snapshot, showsServerName: false)
        #expect(model.stats == snapshot.stats)
        #expect(model.bars == snapshot.bars)
        #expect(model.message == "No energy data")
        #expect(EnergyComplicationRenderModel() == .init())
    }

    // MARK: - Figures

    /// Compared against Foundation's own output rather than a literal, so the expectation follows
    /// the runner's locale the way the complication does.
    @Test func aFigureLosesItsDecimalOnceItReachesThreeDigits() {
        let oneDigit = Double(12.4).formatted(.number.precision(.fractionLength(1)))
        let noDigits = Double(123).formatted(.number.precision(.fractionLength(0)))
        #expect(EnergyComplicationStat.quantity(12.44) == oneDigit)
        #expect(EnergyComplicationStat.quantity(123.4) == noDigits)
    }

    /// Figures are magnitudes — the arrow the widget draws is what carries direction, and the
    /// complication has no room for one, so a net import and a net export read the same way round.
    @Test func aFigureIsAMagnitude() {
        #expect(EnergyComplicationStat.energy(.grid, kWh: -4.2).value == EnergyComplicationStat.quantity(4.2))
    }

    @Test func anEnergyFigureIsLabelledInKilowattHours() {
        let stat = EnergyComplicationStat.energy(.solar, kWh: 12.4)
        #expect(stat.unit == EnergyComplicationStat.energyUnit)
        #expect(stat.series == .solar)
        #expect(stat.id == "solar")
    }

    /// Gas is the one figure that isn't kWh, so it carries whatever unit the recorder reported.
    @Test func aFigureCanCarryAUnitOfItsOwnOrNone() {
        #expect(EnergyComplicationStat(series: .gas, value: "4.8", unit: "m³").unit == "m³")
        #expect(EnergyComplicationStat(series: .gas, value: "4.8", unit: nil).unit == nil)
    }

    // MARK: - Series

    /// Every flow has to be told apart at a glance, which it cannot be if two of them are painted
    /// the same colour.
    @Test func everySeriesHasItsOwnColour() {
        let colours = Set(EnergyComplicationSeries.allCases.map { "\($0.color)" })
        #expect(colours.count == EnergyComplicationSeries.allCases.count)
    }

    /// The two halves of one flow share a glyph, because they are the same meter read in opposite
    /// directions — which is what makes four glyphs for six series right rather than a collision.
    @Test func eachFlowIsDrawnWithItsOwnSymbol() {
        #expect(EnergyComplicationSeries.grid.symbolName == EnergyComplicationSeries.gridReturn.symbolName)
        #expect(EnergyComplicationSeries.batteryOut.symbolName == EnergyComplicationSeries.batteryIn.symbolName)
        #expect(Set(EnergyComplicationSeries.allCases.map(\.symbolName)).count == 4)
        for series in EnergyComplicationSeries.allCases {
            #expect(series.symbolName.isEmpty == false)
            // Resolving the glyph is what proves the name is one the system actually has: a name it
            // doesn't draws a blank rather than failing to build.
            #expect(UIImage(systemName: series.symbolName) != nil, "\(series.rawValue) names no symbol")
        }
    }

    /// The raw values are the payload's own spelling, so renaming a case silently re-points every
    /// stored complication at a different colour.
    @Test func theSeriesNamesAreTheOnesThePayloadCarries() {
        #expect(EnergyComplicationSeries.allCases.map(\.rawValue) == [
            "solar",
            "grid",
            "gridReturn",
            "batteryOut",
            "batteryIn",
            "gas",
        ])
    }

    // MARK: - Sample data

    @Test func theSampleDayCoversTwentyFourHours() {
        #expect(EnergyComplicationSampleData.bars.count == 24)
        #expect(EnergyComplicationSampleData.batteryBars.count == 24)
        #expect(EnergyComplicationSampleData.bars.first?.date == EnergyComplicationSampleData.dayStart)
        // A day with generation, consumption and a surplus to export: all three have to be there or
        // the references stop exercising the stack they were recorded for.
        #expect(EnergyComplicationSampleData.bars.contains { $0.solarUsed > 0 })
        #expect(EnergyComplicationSampleData.bars.contains { $0.gridUsed > 0 })
        #expect(EnergyComplicationSampleData.bars.contains { $0.gridReturned > 0 })
    }

    /// The battery sample stores the midday surplus and gives it back over the evening peak, so it
    /// has to carry both directions.
    @Test func theBatterySampleChargesAndDischarges() {
        #expect(EnergyComplicationSampleData.batteryBars.contains { $0.batteryCharged > 0 })
        #expect(EnergyComplicationSampleData.batteryBars.contains { $0.batteryUsed > 0 })
    }

    /// Figures are derived from the buckets they caption, so a sample's numbers always describe the
    /// chart drawn under them.
    @Test func theSampleFiguresDescribeTheirOwnChart() {
        let stats = EnergyComplicationSampleData.stats
        #expect(stats.map(\.series) == [.grid, .solar])

        let everySource = EnergyComplicationSampleData.allSourceStats
        #expect(everySource.map(\.series) == [.grid, .solar, .batteryOut, .gas])
        #expect(everySource.last?.unit == "m³")
    }

    /// A series the buckets don't carry gets no figure, the way the watch app skips a series the
    /// server doesn't report — a solar figure on a home without panels would be a fiction.
    @Test func aSeriesWithoutBucketsGetsNoFigure() {
        let gridOnly = EnergyComplicationSampleData.bars.map { bar in
            EnergyComplicationChartBar(date: bar.date, solarUsed: 0, gridUsed: bar.gridUsed)
        }
        #expect(EnergyComplicationSampleData.stats(for: gridOnly).map(\.series) == [.grid])
        #expect(EnergyComplicationSampleData.stats(for: []).isEmpty)
    }

    /// Gas is never a bar, so it is the one figure that can stand on a dashboard with no chart at
    /// all — and the one whose unit the caller decides.
    @Test func gasIsAFigureWithoutABar() {
        let gasOnly = EnergyComplicationSampleData.stats(for: [], gas: 4.8)
        #expect(gasOnly.map(\.series) == [.gas])
        #expect(gasOnly.first?.unit == "m³")

        let metered = EnergyComplicationSampleData.stats(
            for: [],
            gas: 52.4,
            gasUnit: EnergyComplicationStat.energyUnit
        )
        #expect(metered.first?.unit == EnergyComplicationStat.energyUnit)
    }

    /// The battery figure is counted the way the dashboard's own total is — discharge positive,
    /// the opposite way round to the grid's — because a battery supplies the home where the grid
    /// bills it.
    @Test func theBatteryFigureCountsDischargeAsPositive() {
        let bars = [
            EnergyComplicationChartBar(
                date: Self.date,
                solarUsed: 0,
                batteryUsed: 3,
                gridUsed: 0,
                batteryCharged: 1
            ),
        ]
        let stats = EnergyComplicationSampleData.stats(for: bars)
        #expect(stats.map(\.series) == [.batteryOut])
        #expect(stats.first?.value == EnergyComplicationStat.quantity(2))
    }
}
