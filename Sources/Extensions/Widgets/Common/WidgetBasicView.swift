import AppIntents
import Shared
import SwiftUI

enum WidgetType: String {
    case button
    case sensor
    case custom
}

struct WidgetBasicView: View {
    let type: WidgetType
    let rows: [[WidgetBasicViewModel]]
    let sizeStyle: WidgetBasicSizeStyle

    var body: some View {
        let spacing = sizeStyle == .compressed ? .zero : Spaces.one
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(rows, id: \.self) { column in
                HStack(spacing: spacing) {
                    ForEach(column) { model in
                        if case let .widgetURL(url) = model.interactionType {
                            Link(destination: url.withWidgetAuthenticity()) {
                                if #available(iOS 18.0, *) {
                                    tintedWrapperView(model: model, sizeStyle: sizeStyle)
                                } else {
                                    normalView(model: model, sizeStyle: sizeStyle)
                                }
                            }
                        } else {
                            if #available(iOS 17.0, *), let intent = intent(for: model) {
                                Button(intent: intent) {
                                    tintedWrapperView(model: model, sizeStyle: sizeStyle)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding([.single, .compressed].contains(sizeStyle) ? 0 : Spaces.one)
    }

    @available(iOS 16.0, *)
    private func tintedWrapperView(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) -> some View {
        switch type {
        case .button, .custom:
            return AnyView(WidgetBasicViewTintedWrapper(
                model: model,
                sizeStyle: sizeStyle,
                viewType: WidgetBasicButtonView.self
            ))
        case .sensor:
            return AnyView(WidgetBasicViewTintedWrapper(
                model: model,
                sizeStyle: sizeStyle,
                viewType: WidgetBasicSensorView.self
            ))
        }
    }

    private func normalView(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) -> some View {
        switch type {
        case .button, .custom:
            return AnyView(WidgetBasicButtonView(
                model: model,
                sizeStyle: sizeStyle,
                tinted: false
            ))
        case .sensor:
            return AnyView(WidgetBasicSensorView(
                model: model,
                sizeStyle: sizeStyle,
                tinted: false
            ))
        }
    }

    @available(iOS 16.4, *)
    private func intent(for model: WidgetBasicViewModel) -> (any AppIntent)? {
        switch model.interactionType {
        case .widgetURL:
            return nil
        case let .appIntent(widgetIntentType):
            switch widgetIntentType {
            case .action:
                let intent = PerformAction()
                intent.action = IntentActionAppEntity(id: model.id, displayString: model.title)
                intent.hapticConfirmation = true
                return intent
            case let .script(id, entityId, serverId, name, showConfirmationNotification):
                let intent = ScriptAppIntent()
                intent.script = .init(
                    id: id,
                    entityId: entityId,
                    serverId: serverId,
                    serverName: "", // not used in this context
                    displayString: name,
                    iconName: "" // not used in this context
                )
                intent.hapticConfirmation = true
                intent.showConfirmationNotification = showConfirmationNotification
                return intent
            case .refresh:
                return ReloadWidgetsAppIntent()
            case let .toggle(entityId, serverId):
                return ReloadWidgetsAppIntent()
            case let .activate(entityId, serverId):
                return ReloadWidgetsAppIntent()
            case let .press(entityId, serverId):
                return ReloadWidgetsAppIntent()
            case let .navigate(serverId, path):
                if #available(iOS 18, *) {
                    let panel = HAPanel(icon: nil, title: "", path: path, component: "", showInSidebar: false)
                    let page = PageAppEntity(id: "", panel: panel, serverId: serverId)
                    let intent = OpenPageAppIntent()
                    intent.page = page
                    return intent
                } else {
                    return ReloadWidgetsAppIntent()
                }
            case let .assist(serverId, pipelineId, startListening):
                return ReloadWidgetsAppIntent()
            }
        }
    }
}

#Preview {
    WidgetBasicView(
        type: .button,
        rows: [[
            .init(
                id: "1",
                title: "Title",
                subtitle: "Subtitle",
                interactionType: .appIntent(.refresh),
                icon: .abTestingIcon
            ),
        ]],
        sizeStyle: .compressed
    )
}
