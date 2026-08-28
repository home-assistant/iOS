import AppIntents
import Shared
import SwiftUI
import WidgetKit

/// What a widget tile does when it is tapped.
///
/// The design system draws the tiles and knows nothing about App Intents or deep links, so this is
/// where a rendered tile is wrapped in the control that runs it — and where a tile waiting on a
/// confirmation is swapped for the confirmation form instead.
///
/// A tile whose icon controls its entity is split in two, the way the frontend's tile card is: the
/// icon runs the entity's action and the rest of the tile opens it in the app. ``regions`` wraps
/// each half; ``content`` then leaves such a tile alone, because it already carries its controls.
struct WidgetTileInteraction {
    let type: WidgetType
    let family: WidgetFamily

    func content(model: WidgetBasicViewModel, sizeStyle: WidgetTileSizeStyle, tile: AnyView) -> AnyView {
        if #available(iOS 17, *) {
            if model.showConfirmation {
                return AnyView(confirmationContent(model: model, sizeStyle: sizeStyle))
            } else if isSplit(model) {
                // Already interactive: `regions` wrapped each half on the way in.
                return tile
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

    /// The two halves of a split tile: the icon runs the item's own action, and the rest of the tile
    /// opens the item. `nil` for every tile that is a single control, which is all of them before
    /// iOS 17 and all of them while a confirmation is pending.
    func regions(model: WidgetBasicViewModel) -> WidgetTileRegions? {
        guard #available(iOS 17, *), !model.showConfirmation, let iconInteractionType = model.iconInteractionType else {
            return nil
        }
        return WidgetTileRegions(
            icon: { icon in
                AnyView(control(model: model, interactionType: iconInteractionType, isIcon: true, content: icon))
            },
            body: { body in
                AnyView(control(model: model, interactionType: model.interactionType, isIcon: false, content: body))
            }
        )
    }

    private func isSplit(_ model: WidgetBasicViewModel) -> Bool {
        model.iconInteractionType != nil
    }

    /// The action a tap runs when the whole tile — or the confirmation standing in for it — is what
    /// was tapped. On a split tile that is the icon's action: the body only opens the item, which is
    /// nothing to confirm and nothing to run in place.
    private func actionInteractionType(for model: WidgetBasicViewModel) -> WidgetInteractionType {
        model.iconInteractionType ?? model.interactionType
    }

    /// One half of a split tile, wrapped in whatever runs it. Only the icon asks for confirmation:
    /// opening the item in the app changes nothing, so there is nothing to confirm first.
    @available(iOS 17.0, *)
    @ViewBuilder
    private func control(
        model: WidgetBasicViewModel,
        interactionType: WidgetInteractionType,
        isIcon: Bool,
        content: AnyView
    ) -> some View {
        if isIcon, model.requiresConfirmation {
            Button(intent: confirmationStateIntent(for: model)) {
                content
            }
            .buttonStyle(.plain)
        } else if case let .widgetURL(url) = interactionType {
            // Without the token `IncomingURLHandler` drops the `server` parameter and opens server
            // selection instead of the widget's server.
            Link(destination: url.withWidgetAuthenticity()) {
                content
            }
        } else if let intent = intent(for: interactionType, model: model) {
            Button(intent: intent) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
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
            tinted: false
        )
    }

    @available(iOS 17.0, *)
    private func confirmationStateIntent(for model: WidgetBasicViewModel)
        -> UpdateWidgetItemConfirmationStateAppIntent {
        let intent = UpdateWidgetItemConfirmationStateAppIntent()
        intent.widgetId = model.widgetId
        intent.serverUniqueId = model.id
        return intent
    }

    @available(iOS 17.0, *)
    private func intent(for model: WidgetBasicViewModel, isConfirmationDone: Bool = true) -> (any AppIntent)? {
        intent(
            for: actionInteractionType(for: model),
            model: model,
            isConfirmationDone: isConfirmationDone
        )
    }

    @available(iOS 17.0, *)
    private func intent(
        for interactionType: WidgetInteractionType,
        model: WidgetBasicViewModel,
        isConfirmationDone: Bool = true
    ) -> (any AppIntent)? {
        switch interactionType {
        case .widgetURL:
            return nil
        case let .appIntent(widgetIntentType):
            // When confirmation is required and this method wasn't called from confirmation button
            if model.requiresConfirmation, !isConfirmationDone {
                return confirmationStateIntent(for: model)
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
            if case let .widgetURL(url) = actionInteractionType(for: model) {
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
        Button(intent: confirmationStateIntent(for: model)) {
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
