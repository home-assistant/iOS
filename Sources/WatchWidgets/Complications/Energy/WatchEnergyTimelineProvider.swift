import AppIntents
import HAWatchComplications
import WidgetKit

/// Serves the energy complication from what the watch app left in the app group.
///
/// There is no fetch here, unlike the entity complication's provider: energy preferences and
/// long-term statistics are websocket commands and this extension links nothing that speaks them.
/// The app refreshes the payload and reloads the timelines; this reads the result and asks to be
/// called again on the same cadence the other complications use, so a face that was woken between
/// refreshes still picks up whatever landed in the meantime.
@available(watchOS 10.0, *)
struct WatchEnergyTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WatchEnergyEntry
    typealias Intent = WatchEnergyConfigurationIntent

    func placeholder(in context: Context) -> WatchEnergyEntry {
        WatchEnergyEntry(date: Date(), model: Self.sampleModel)
    }

    func snapshot(for configuration: WatchEnergyConfigurationIntent, in context: Context) async -> WatchEnergyEntry {
        // The complication picker renders a preview per candidate. Showing the sample day there is
        // both instant and honest: it shows what the complication looks like without passing a
        // possibly-stale reading off as the current one.
        guard !context.isPreview else { return previewEntry(for: configuration) }
        return entry(for: configuration)
    }

    func timeline(
        for configuration: WatchEnergyConfigurationIntent,
        in context: Context
    ) async -> Timeline<WatchEnergyEntry> {
        guard !context.isPreview else {
            return Timeline(entries: [previewEntry(for: configuration)], policy: .never)
        }
        return Timeline(
            entries: [entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(WatchWidgetConstants.timelineRefreshInterval))
        )
    }

    /// One ready-made complication per server, which is the whole point: the picker's list grows and
    /// shrinks with the servers the app has, and the user never configures anything.
    ///
    /// Before the watch app has written its first payload there are no servers to list, so a single
    /// unconfigured entry stands in — otherwise the complication would be missing from the picker
    /// exactly when someone goes looking for it.
    func recommendations() -> [AppIntentRecommendation<WatchEnergyConfigurationIntent>] {
        let snapshots = WatchEnergyComplicationStore.snapshots()
        guard !snapshots.isEmpty else {
            return [AppIntentRecommendation(
                intent: WatchEnergyConfigurationIntent(),
                description: WatchWidgetStrings.energyTitle
            )]
        }
        return snapshots.map { snapshot in
            AppIntentRecommendation(
                intent: WatchEnergyConfigurationIntent(server: WatchEnergyServerEntity(snapshot: snapshot)),
                // The server's own name, not "Energy": with one entry per server the name is the only
                // thing telling the picker's rows apart.
                description: snapshot.serverName
            )
        }
    }

    private func entry(for configuration: WatchEnergyConfigurationIntent) -> WatchEnergyEntry {
        guard let snapshot = WatchEnergyComplicationStore.snapshot(serverId: configuration.server?.id) else {
            return WatchEnergyEntry(
                date: Date(),
                model: EnergyComplicationRenderModel(message: WatchWidgetStrings.energyNoData)
            )
        }
        return WatchEnergyEntry(
            date: snapshot.date,
            model: EnergyComplicationRenderModel(
                snapshot: snapshot,
                showsServerName: WatchEnergyComplicationStore.showsServerName()
            )
        )
    }

    /// The gallery's card: the sample day, captioned with the server the entry is for so a home with
    /// several can tell which row is which while picking.
    private func previewEntry(for configuration: WatchEnergyConfigurationIntent) -> WatchEnergyEntry {
        var model = Self.sampleModel
        if WatchEnergyComplicationStore.showsServerName() {
            model.serverName = configuration.server?.name
        }
        return WatchEnergyEntry(date: Date(), model: model)
    }

    private static var sampleModel: EnergyComplicationRenderModel {
        EnergyComplicationRenderModel(
            stats: EnergyComplicationSampleData.stats,
            bars: EnergyComplicationSampleData.bars
        )
    }
}
