import Shared
import SwiftUI

/// An Assist pipeline or Assist prompt configured as a home item. Tapping opens the full-screen
/// Assist session owned by `WatchHomeView`: a pipeline item starts listening, a prompt item sends
/// its text straight away.
struct WatchAssistItemRow: View {
    let item: MagicItem
    let itemInfo: MagicItem.Info
    var layout: WatchLayout = .list
    @Environment(\.watchPresentAssist) private var presentAssist

    var body: some View {
        Button {
            presentAssist(.session(
                serverId: item.serverId,
                // An empty id is the "Preferred" pipeline; a pipeline item without an override runs
                // the pipeline its own id points at.
                pipelineId: item.assistPipelineId ?? item.id,
                prompt: item.type == .assistPrompt ? item.assistPrompt : nil
            ))
        } label: {
            label
        }
        .modify { view in
            if layout == .grid {
                view.watchHomeItemGridStyle(tint: backgroundForWatchItem)
            } else {
                view
                    .frame(maxWidth: .infinity)
                    .watchHomeItemRowStyle(tint: backgroundForWatchItem)
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if layout == .grid {
            gridIcon
        } else {
            WatchHomeItemLabel(
                name: item.name(info: itemInfo),
                subtitle: subtitle,
                textColor: textColor,
                icon: { iconView }
            )
        }
    }

    /// A prompt item shows the text it will send — the name alone doesn't say what will be asked.
    private var subtitle: String? {
        guard item.type == .assistPrompt,
              let prompt = item.assistPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
              !prompt.isEmpty else {
            return nil
        }
        return prompt
    }

    private var iconColor: UIColor {
        if let hex = item.customization?.iconColor ?? itemInfo.customization?.iconColor {
            .init(hex: hex)
        } else {
            .white
        }
    }

    private var iconView: some View {
        VStack {
            Image(uiImage: item.icon(info: itemInfo).image(
                ofSize: .init(width: 24, height: 24),
                color: iconColor
            ))
            .foregroundStyle(Color(uiColor: iconColor))
            .padding()
        }
        .watchRowIconContainer(color: iconColor)
    }

    private var gridIcon: some View {
        Image(uiImage: item.icon(info: itemInfo).image(
            ofSize: .init(width: 28, height: 28),
            color: iconColor
        ))
        .foregroundStyle(Color(uiColor: iconColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(item.name(info: itemInfo)))
    }

    private var textColor: Color {
        if let textColor = item.customization?.textColor {
            .init(uiColor: .init(hex: textColor))
        } else {
            .white
        }
    }

    private var backgroundForWatchItem: Color? {
        if let backgroundColor = item.customization?.backgroundColor {
            Color(uiColor: .init(hex: backgroundColor))
        } else {
            nil
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    return List {
        WatchAssistItemRow(
            item: .init(
                id: "pipeline-1",
                serverId: "1",
                type: .assistPipeline,
                customization: .init(iconColor: MagicItem.defaultAssistIconColorHex)
            ),
            itemInfo: .init(id: "1-pipeline-1", name: "Home Assistant", iconName: "mdi:microphone")
        )
        WatchAssistItemRow(
            item: .init(
                id: "prompt-1",
                serverId: "1",
                type: .assistPrompt,
                customization: .init(iconColor: MagicItem.defaultAssistIconColorHex),
                displayText: "Good night",
                assistPrompt: "Turn off all the lights",
                assistPipelineId: ""
            ),
            itemInfo: .init(id: "1-prompt-1", name: "Preferred", iconName: "mdi:message-processing-outline")
        )
    }
}
