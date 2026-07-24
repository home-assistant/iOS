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
        return WatchWidgetEntry(
            date: entry.date,
            family: entry.family,
            complication: entry.complication?.previewVariant
        )
    }

    func timeline(
        for configuration: WatchWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<WatchWidgetEntry> {
        // Self-fetch live values on the widget's own WidgetKit budget so complications stay fresh even
        // when the WatchApp isn't woken. This updates the app-group snapshot store that `entry(...)` reads.
        await WatchWidgetLiveFetch.refresh(configuredID: configuration.complication?.id)
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
            complication: WatchWidgetComplicationSnapshotStore.complication(
                for: context.family,
                configuredID: configuration.complication?.id
            ) ?? .placeholder
        )
    }
}
