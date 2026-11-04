import AppIntents
import WidgetKit

@available(watchOS 10.0, *)
struct WatchWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Home Assistant"
    static let description = IntentDescription("Show a Home Assistant complication")

    @Parameter(title: "Complication")
    var complication: WatchWidgetComplicationEntity?

    init() {
        self.complication = nil
    }

    init(complication: WatchWidgetComplicationEntity) {
        self.complication = complication
    }

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}

@available(watchOS 10.0, *)
struct WatchWidgetAppIntentProvider: AppIntentTimelineProvider {
    typealias Entry = WatchWidgetEntry
    typealias Intent = WatchWidgetConfigurationIntent

    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(date: Date(), family: context.family, complication: .placeholder)
    }

    func snapshot(for configuration: WatchWidgetConfigurationIntent, in context: Context) async -> WatchWidgetEntry {
        let entry = entry(for: configuration, in: context)
        // The complication picker/gallery asks for a preview snapshot: render the complication's
        // identity (name, icon, gauge, colors) with a neutral value instead of whatever live value
        // happens to be cached — no fetch, instant, and never presents stale data as current.
        guard context.isPreview else { return entry }
        return previewEntry(from: entry)
    }

    func timeline(
        for configuration: WatchWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<WatchWidgetEntry> {
        // Picking a complication renders one preview per candidate per family, so a fetch here would
        // multiply into a burst of requests in a single extension process — while the picker is the one
        // place a live value must not be shown anyway. Serve mocked identity-only data and never reload:
        // the real timeline is built once the complication is actually placed on the face.
        guard !context.isPreview else {
            return Timeline(entries: [previewEntry(from: entry(for: configuration, in: context))], policy: .never)
        }

        // Fetch only the complication this instance renders, not every configured one. Each instance on
        // the face gets its own `timeline(for:in:)` call, so fetching them all here squared the work and
        // was what pushed the extension past its watchdog budget.
        await WatchWidgetLiveFetch.refresh(complicationID: renderedSnapshot(for: configuration, in: context)?.id)

        return Timeline(
            entries: [entry(for: configuration, in: context)],
            policy: .after(Date().addingTimeInterval(WatchWidgetConstants.timelineRefreshInterval))
        )
    }

    func recommendations() -> [AppIntentRecommendation<WatchWidgetConfigurationIntent>] {
        WatchWidgetComplicationSnapshotStore.recommendations().map { snapshot in
            let intent = WatchWidgetConfigurationIntent(complication: WatchWidgetComplicationEntity(snapshot: snapshot))
            return AppIntentRecommendation(intent: intent, description: snapshot.recommendationTitle)
        }
    }

    private func entry(
        for configuration: WatchWidgetConfigurationIntent,
        in context: Context
    ) -> WatchWidgetEntry {
        WatchWidgetEntry(
            date: Date(),
            family: context.family,
            complication: renderedSnapshot(for: configuration, in: context) ?? .placeholder
        )
    }

    /// The stored snapshot this instance actually renders. The configured id can no longer resolve (the
    /// complication was deleted, or recreated with a new id), in which case the store falls back to a
    /// family match — so this, not the configured id, is what the self fetch must target.
    private func renderedSnapshot(
        for configuration: WatchWidgetConfigurationIntent,
        in context: Context
    ) -> WatchWidgetComplicationSnapshot? {
        WatchWidgetComplicationSnapshotStore.complication(
            for: context.family,
            configuredID: configuration.complication?.id
        )
    }

    private func previewEntry(from entry: WatchWidgetEntry) -> WatchWidgetEntry {
        WatchWidgetEntry(
            date: entry.date,
            family: entry.family,
            complication: entry.complication?.previewVariant
        )
    }
}
