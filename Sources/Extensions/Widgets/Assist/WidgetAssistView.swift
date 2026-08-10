import Shared
import SwiftUI
import WidgetKit

struct WidgetAssistView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    private let entry: WidgetAssistEntry
    private let tinted: Bool

    private var subtitle: String {
        guard let pipeline = entry.pipelines.first else {
            return L10n.Widgets.Assist.unknownConfiguration
        }

        return pipeline.name
    }

    init(entry: WidgetAssistEntry, tinted: Bool) {
        self.entry = entry
        self.tinted = tinted
    }

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch widgetFamily {
        case .accessoryCircular:
            accessoryCircular
                .widgetBackground(Color.clear)
                .widgetURL(entry.widgetURL)
        case .systemSmall:
            singleHomeScreenItem
                .widgetBackground(Color.clear)
                .widgetURL(entry.widgetURL)
        default:
            pipelinesGrid
        }
    }

    private var accessoryCircular: some View {
        WidgetCircularView(icon: MaterialDesignIcons.messageProcessingOutlineIcon)
    }

    /// One tile per configured pipeline, each deep linking straight into its own Assist
    /// conversation. Backgrounds and tinting are handled by `WidgetBasicContainerView`.
    private var pipelinesGrid: some View {
        WidgetBasicContainerView(
            emptyViewGenerator: {
                AnyView(WidgetEmptyView(message: L10n.Widgets.Assist.notConfigured))
            },
            contents: {
                let showSubtitle = !entry.isPreview && Current.servers.all.count > 1
                return entry.pipelines.map { pipeline in
                    WidgetBasicViewModel(
                        id: pipeline.id,
                        title: pipeline.name,
                        subtitle: showSubtitle ? serverName(for: pipeline) : nil,
                        interactionType: .widgetURL(
                            WidgetAssistEntry.widgetURL(for: pipeline, withVoice: entry.withVoice)
                        ),
                        icon: .messageProcessingOutlineIcon
                    )
                }
            }(),
            type: .button
        )
    }

    private func serverName(for pipeline: AssistPipelineEntity) -> String? {
        let server = Current.servers.all.first { $0.identifier.rawValue == pipeline.serverId }
            ?? Current.servers.all.first
        return server?.info.name
    }

    private var singleHomeScreenItem: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Spacer()
            Group {
                Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                    ofSize: .init(width: 56, height: 56),
                    color: UIColor.haPrimary
                ))
                .foregroundStyle(.ultraThickMaterial)
                VStack(spacing: .zero) {
                    Group {
                        Text(verbatim: L10n.Widgets.Assist.actionTitle)
                            .font(.footnote.bold())
                            .foregroundColor(Color(uiColor: .label))
                        Text(subtitle)
                            .font(.footnote.weight(.light))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .modify { view in
                if #available(iOS 18, *) {
                    view.widgetAccentable()
                } else {
                    view
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spaces.two)
        .background(tinted ? Color.clear : Color(uiColor: .systemBackground))
    }
}

#Preview {
    WidgetAssistView(
        entry: .init(
            pipelines: [
                .init(id: "preview-pipeline", serverId: "preview-server", name: "Home Assistant"),
            ],
            isPreview: true
        ),
        tinted: false
    )
}
