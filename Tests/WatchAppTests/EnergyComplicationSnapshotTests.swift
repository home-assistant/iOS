import Foundation
import HAWatchComplications
import Testing

/// The payload the watch app leaves in the app group for the widget extension, and the mapping the
/// extension makes of it. The two processes never share a type instance — only this JSON — so a
/// round trip is the only thing standing between a rename and a face that silently stops updating.
struct EnergyComplicationSnapshotTests {
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

    @Test func survivesTheTripThroughTheAppGroup() throws {
        let original = [
            Self.snapshot(stats: EnergyComplicationSampleData.stats, bars: EnergyComplicationSampleData.bars),
            Self.snapshot(serverId: "server-2", serverName: "Cabin", message: "No energy data"),
        ]
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode([EnergyComplicationSnapshot].self, from: data) == original)
    }

    @Test func writesAndReadsBackFromDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "EnergyComplicationSnapshotTests"))
        defaults.removePersistentDomain(forName: "EnergyComplicationSnapshotTests")
        let snapshots = [Self.snapshot(stats: EnergyComplicationSampleData.stats)]

        EnergyComplicationSnapshot.write(snapshots, to: defaults)

        #expect(EnergyComplicationSnapshot.read(from: defaults) == snapshots)
        defaults.removePersistentDomain(forName: "EnergyComplicationSnapshotTests")
    }

    @Test func readsNothingWhenTheStoreIsEmpty() {
        #expect(EnergyComplicationSnapshot.read(from: nil).isEmpty)
    }

    /// A server whose dashboard couldn't be read still belongs in the store: it is what keeps that
    /// server's complication in the picker instead of making it vanish until the next refresh.
    @Test func aMessageOnlySnapshotHasNoContent() {
        #expect(Self.snapshot(message: "No energy data").hasContent == false)
        #expect(Self.snapshot(stats: EnergyComplicationSampleData.stats).hasContent)
    }

    /// Early in the day the server answers with buckets that are all zero. That is a period with
    /// nothing in it, not a chart.
    @Test func barsWithNothingInThemCountAsEmpty() {
        let bar = EnergyComplicationChartBar(date: Self.date, solarUsed: 0, gridUsed: 0)
        #expect(bar.isEmpty)
        #expect(Self.snapshot(bars: [bar]).hasContent == false)
        #expect(Self.snapshot(bars: EnergyComplicationSampleData.bars).hasContent)
    }

    /// The name is the caller's call, because only the caller can see how many servers there are.
    @Test func theServerNameIsOnlyCarriedWhenItIsWorthALine() {
        let snapshot = Self.snapshot(stats: EnergyComplicationSampleData.stats)
        #expect(EnergyComplicationRenderModel(snapshot: snapshot, showsServerName: true).serverName == "Home")
        #expect(EnergyComplicationRenderModel(snapshot: snapshot, showsServerName: false).serverName == nil)
    }

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
}
