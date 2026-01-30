import AppIntents
import Foundation
import Shared
import SwiftUI

struct WidgetBasicButtonView: WidgetBasicViewProtocol {
    @Environment(\.widgetFamily) private var widgetFamily

    let model: WidgetBasicViewModel
    let sizeStyle: WidgetBasicSizeStyle
    let tinted: Bool

    init(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle, tinted: Bool) {
        self.model = model
        self.sizeStyle = sizeStyle
        self.tinted = tinted
    }

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular, .accessoryRectangular:
            WidgetCircularView(icon: model.icon)
        case .accessoryInline:
            Label {
                Text(model.title)
            } icon: {
                Image(uiImage: model.icon.image(ofSize: .init(width: 10, height: 10), color: .white))
            }
        default:
            tileView
        }
    }

    private var text: some View {
        Text(verbatim: model.title)
            .font(sizeStyle.textFont)
            .fontWeight(.semibold)
            .multilineTextAlignment(.leading)
            .foregroundStyle(model.useCustomColors ? model.textColor : Color(uiColor: .label))
            .lineLimit(2)
    }

    @ViewBuilder
    private var subtext: some View {
        if let subtitle = model.subtitle {
            Text(verbatim: subtitle)
                .font(sizeStyle.subtextFont)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var iconView: some View {
        VStack {
            Text(verbatim: model.icon.unicode)
                .font(sizeStyle.iconFont)
                .foregroundColor(model.iconColor)
                .fixedSize(horizontal: false, vertical: false)
        }
        .frame(width: sizeStyle.iconCircleSize.width, height: sizeStyle.iconCircleSize.height)
        .background(model.showIconBackground ? model.iconColor.opacity(0.3) : Color.clear)
        .clipShape(Circle())
    }

    /// Icon wrapped with its own interaction type (used for separate icon tap)
    @available(iOS 17.0, *)
    @ViewBuilder
    private var interactiveIcon: some View {
        if model.requiresConfirmation {
            // When confirmation is required, trigger confirmation flow
            Button(intent: {
                let intent = UpdateWidgetItemConfirmationStateAppIntent()
                intent.serverUniqueId = model.id
                intent.widgetId = model.widgetId
                return intent
            }()) {
                iconView
            }
            .buttonStyle(.plain)
        } else if let iconIntent = WidgetInteractionIntentFactory.intent(
            for: model.interactionType,
            model: model
        ) {
            Button(intent: iconIntent) {
                iconView
            }
            .buttonStyle(.plain)
        } else if case let .widgetURL(url) = model.interactionType {
            Link(destination: url.withWidgetAuthenticity()) {
                iconView
            }
        } else {
            iconView
        }
    }

    private var tileView: some View {
        VStack(alignment: .leading) {
            Group {
                switch sizeStyle {
                case .regular, .compact, .compressed:
                    HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
                        if #available(iOS 17.0, *) {
                            interactiveIcon
                        } else {
                            iconView
                        }
                        VStack(alignment: .leading, spacing: .zero) {
                            text
                            subtext
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding([.leading, .trailing], DesignSystem.Spaces.oneAndHalf)
                case .single, .expanded:
                    VStack(alignment: .leading, spacing: 0) {
                        if #available(iOS 17.0, *) {
                            interactiveIcon
                        } else {
                            iconView
                        }
                        Spacer()
                        text
                        subtext
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, sizeStyle == .regular ? 10 : /* use default */ nil)
                }
            }
            .modify { view in
                if #available(iOS 18, *) {
                    view.widgetAccentable()
                } else {
                    view
                }
            }
        }
        .tileCardStyle(sizeStyle: sizeStyle, model: model, tinted: tinted)
    }
}

/// Factory for creating intents from interaction types
@available(iOS 17.0, *)
enum WidgetInteractionIntentFactory {
    /// Creates an AppIntent for the given interaction type
    /// - Parameters:
    ///   - interactionType: The type of interaction
    ///   - model: The view model containing widget item data
    ///   - checkConfirmation: If true, returns confirmation intent when model.requiresConfirmation is true
    /// - Returns: An AppIntent if one can be created, nil otherwise
    static func intent(
        for interactionType: WidgetInteractionType,
        model: WidgetBasicViewModel,
        checkConfirmation: Bool = false
    ) -> (any AppIntent)? {
        switch interactionType {
        case .widgetURL, .noAction:
            return nil
        case let .appIntent(widgetIntentType):
            // When confirmation is required and caller wants to check for it
            if checkConfirmation, model.requiresConfirmation {
                let intent = UpdateWidgetItemConfirmationStateAppIntent()
                intent.widgetId = model.widgetId
                intent.serverUniqueId = model.id
                return intent
            }
            return intentForWidgetType(widgetIntentType, model: model)
        }
    }

    /// Creates an AppIntent for the specific widget intent type
    private static func intentForWidgetType(
        _ widgetIntentType: WidgetIntentType,
        model: WidgetBasicViewModel
    ) -> (any AppIntent)? {
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
        case let .toggle(entityId, domain, serverId):
            let intent = CustomWidgetToggleAppIntent()
            intent.domain = domain
            intent.entityId = entityId
            intent.serverId = serverId
            intent.widgetShowingStates = model.subtitle != nil
            return intent
        case let .activate(entityId, domain, serverId):
            let intent = CustomWidgetActivateAppIntent()
            intent.domain = domain
            intent.entityId = entityId
            intent.serverId = serverId
            return intent
        case let .press(entityId, domain, serverId):
            let intent = CustomWidgetPressButtonAppIntent()
            intent.domain = domain
            intent.entityId = entityId
            intent.serverId = serverId
            return intent
        }
    }
}
