import AppIntents
import Shared
import SwiftUI
import WidgetKit

// Modern App Intents configuration for the Assist widget, replacing the legacy `AssistInAppIntent`
// (generated from Intents.intentdefinition). Only one pipeline is chosen, so there's no size map.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetAssistAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.assist.title", defaultValue: "Assist")
    static let description = IntentDescription(
        .init("widgets.assist.description", defaultValue: "Start Assist.")
    )

    @Parameter(title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline"))
    var pipeline: AssistPipelineEntity?

    @Parameter(
        title: .init("app_intents.controls.assist.parameter.with_voice", defaultValue: "With voice"),
        default: true
    )
    var withVoice: Bool

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}

@available(iOS 17.0, *)
struct WidgetAssist: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.assist.rawValue,
            intent: WidgetAssistAppIntent.self,
            provider: WidgetAssistAppIntentTimelineProvider(),
            content: { entry in
                content(for: entry)
                    .widgetBackground(Color.clear)
                    .widgetURL(Self.widgetURL(for: entry))
            }
        )
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Assist.title)
        .description(L10n.Widgets.Assist.description)
        .supportedFamilies(supportedFamilies)
        .disfavoredInCarPlayIfAvailable(for: supportedFamilies)
    }

    @ViewBuilder
    private func content(for entry: WidgetAssistEntry) -> some View {
        if #available(iOS 18.0, *) {
            WidgetAssistViewTintedWrapper(entry: entry)
        } else {
            WidgetAssistView(entry: entry, tinted: false)
        }
    }

    /// Deep link that opens Assist for the configured pipeline; falls back to the app root when the
    /// widget isn't configured yet.
    private static func widgetURL(for entry: WidgetAssistEntry) -> URL {
        guard let pipeline = entry.pipeline, !pipeline.serverId.isEmpty else {
            return AppConstants.deeplinkURL
        }
        return AppConstants.assistDeeplinkURL(
            serverId: pipeline.serverId,
            pipelineId: pipeline.pipelineId ?? "",
            startListening: entry.withVoice
        ) ?? AppConstants.deeplinkURL
    }

    private var supportedFamilies: [WidgetFamily] {
        var supportedFamilies: [WidgetFamily] = [.systemSmall]

        if #available(iOSApplicationExtension 16.0, *) {
            supportedFamilies.append(.accessoryCircular)
        }

        return supportedFamilies
    }
}
