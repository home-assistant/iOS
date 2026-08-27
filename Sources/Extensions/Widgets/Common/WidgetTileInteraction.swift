import AppIntents
import Shared
import SwiftUI
import WidgetKit

/// What a widget tile does when it is tapped.
///
/// The design system draws the tiles and knows nothing about App Intents or deep links, so this is
/// where a rendered tile is wrapped in the control that runs it — and where a tile waiting on a
/// confirmation is swapped for the confirmation form instead.
struct WidgetTileInteraction {
    let type: WidgetType
    let family: WidgetFamily

    func content(model: WidgetBasicViewModel, sizeStyle: WidgetTileSizeStyle, tile: AnyView) -> AnyView {
        if #available(iOS 17, *) {
            if model.showConfirmation {
                return AnyView(confirmationContent(model: model, sizeStyle: sizeStyle))
            } else if case .widgetURL = model.interactionType {
                if model.requiresConfirmation {
                    return AnyView(linkThatRequiresConfirmation(model: model, sizeStyle: sizeStyle, tile: tile))
                } else {
                    return AnyView(legacyLinkContent(model: model, sizeStyle: sizeStyle, tile: tile))
                }
            } else if let intent = intent(for: model, isConfirmationDone: false) {
                return AnyView(
                    Button(intent: intent) {
                        tile
                    }
                    .buttonStyle(.plain)
                )
            } else {
                return AnyView(Text(verbatim: "Unknown widget configuration (2)"))
            }
        } else {
            return AnyView(legacyLinkContent(model: model, sizeStyle: sizeStyle, tile: tile))
        }
    }

    /// The tile drawn without the widget's accent tint, for the versions of iOS that only tinted
    /// buttons and left links in full colour.
    private func plainTile(model: WidgetBasicViewModel, sizeStyle: WidgetTileSizeStyle) -> some View {
        WidgetTileView(
            model: model.tileModel,
            sizeStyle: sizeStyle,
            family: family,
            kind: type.tileKind,
            tinted: false,
            logo: Image(.logo)
        )
    }

    @available(iOS 17.0, *)
    private func intent(for model: WidgetBasicViewModel, isConfirmationDone: Bool = true) -> (any AppIntent)? {
        switch model.interactionType {
        case .widgetURL:
            return nil
        case let .appIntent(widgetIntentType):
            // When confirmation is required and this method wasn't called from confirmation button
            if model.requiresConfirmation, !isConfirmationDone {
                let intent = UpdateWidgetItemConfirmationStateAppIntent()
                intent.widgetId = model.widgetId
                intent.serverUniqueId = model.id
                return intent
            }
            switch widgetIntentType {
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

    /// The confirmation a tile turns into once it has been asked to run something that requires one.
    @available(iOS 17.0, *)
    private func confirmationContent(
        model: WidgetBasicViewModel,
        sizeStyle: WidgetTileSizeStyle
    ) -> some View {
        let confirmationIntent = intent(for: model, isConfirmationDone: true)
        let confirmationURL: URL? = {
            if case let .widgetURL(url) = model.interactionType {
                return url
            } else {
                return nil
            }
        }()
        let cancellationIntent = ResetAllCustomWidgetConfirmationAppIntent()
        return WidgetTileConfirmationView(
            title: L10n.Alert.Confirmation.Generic.title,
            sizeStyle: sizeStyle,
            confirmIsButton: confirmationIntent != nil,
            cancel: { label in
                AnyView(Button(intent: cancellationIntent) { label })
            },
            confirm: { label in
                if let confirmationURL {
                    // Same as the unconfirmed path: without the token `IncomingURLHandler` drops the
                    // `server` parameter and opens server selection instead of the widget's server.
                    return AnyView(Link(destination: confirmationURL.withWidgetAuthenticity()) { label })
                } else if let confirmationIntent {
                    return AnyView(Button(intent: confirmationIntent) { label })
                } else {
                    return AnyView(EmptyView())
                }
            }
        )
    }

    /// A deep link that has to be confirmed first: tapping it only flips the widget into its
    /// confirmation state, and the form is what actually follows the link.
    @available(iOS 17.0, *)
    private func linkThatRequiresConfirmation(
        model: WidgetBasicViewModel,
        sizeStyle: WidgetTileSizeStyle,
        tile: AnyView
    ) -> some View {
        Button(intent: {
            let intent = UpdateWidgetItemConfirmationStateAppIntent()
            intent.serverUniqueId = model.id
            intent.widgetId = model.widgetId
            return intent
        }()) {
            if #available(iOS 18.0, *) {
                tile
            } else {
                plainTile(model: model, sizeStyle: sizeStyle)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    // This is the only widget we can present prior to iOS 17, because it doesn't support AppIntents
    private func legacyLinkContent(
        model: WidgetBasicViewModel,
        sizeStyle: WidgetTileSizeStyle,
        tile: AnyView
    ) -> some View {
        if case let .widgetURL(url) = model.interactionType {
            Link(destination: url.withWidgetAuthenticity()) {
                if #available(iOS 18.0, *) {
                    tile
                } else {
                    plainTile(model: model, sizeStyle: sizeStyle)
                }
            }
        } else {
            Text(verbatim: "Unknown widget configuration")
        }
    }
}
