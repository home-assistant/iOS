import AppIntents
import WidgetKit

@available(watchOS 10.0, *)
struct WatchWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Home Assistant"
    static let description = IntentDescription("Show a Home Assistant complication")

    @Parameter(title: "Complication")
    var complication: WatchWidgetComplicationEntity?

    init() {
        complication = nil
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
        entry(for: configuration, in: context)
    }

    func timeline(
        for configuration: WatchWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<WatchWidgetEntry> {
        Timeline(
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
