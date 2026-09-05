import Foundation
import GRDB
import HADesignSystem
import HAKit
import HAKit_PromiseKit
import PromiseKit
import SwiftUI

/// Object that represents iOS item that can be displayed in Watch, Widgets, CarPlay and perform different action types
public struct MagicItem: Codable, Equatable, Hashable {
    /// Identity-based equality for use in sets/dictionaries and caching.
    /// Compares only stable identity fields, not mutable content.
    public static func == (lhs: MagicItem, rhs: MagicItem) -> Bool {
        lhs.id == rhs.id
            && lhs.serverId == rhs.serverId
            && lhs.type == rhs.type
    }

    /// Identity-based hashing consistent with `==`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(serverId)
        hasher.combine(type)
    }

    /// Content-based equality for UI/change detection.
    /// Unlike `==`, this includes mutable fields.
    public func contentEquals(_ other: MagicItem) -> Bool {
        id == other.id
            && serverId == other.serverId
            && type == other.type
            && customization == other.customization
            && action == other.action
            && tapAction == other.tapAction
            && displayText == other.displayText
            && assistPrompt == other.assistPrompt
            && assistPipelineId == other.assistPipelineId
            && items == other.items
    }

    /// Id match it's type Id, e.g. "script.open_gate"
    public let id: String
    public var serverId: String
    public let type: ItemType
    public var customization: Customization?
    /// What the item's icon runs when tapped. On a widget tile the icon is the entity's own
    /// control, so this is the action the tile performs in place.
    public var action: ItemAction?
    /// What a tap anywhere on the tile other than its icon runs, mirroring the frontend tile card's
    /// `tap_action`: by default the entity's more-info dialog, while the icon keeps the control.
    public var tapAction: ItemAction?
    public var displayText: String?
    public var assistPrompt: String?
    public var assistPipelineId: String?
    public var items: [MagicItem]? /// Only for folder type, represents items inside the folder

    /// Server unique ID - e.g. "EB1364-script.open_gate"
    public var serverUniqueId: String {
        "\(serverId)-\(id)"
    }

    /// A hash value that includes mutable content fields, for use as a SwiftUI animation/change detection value.
    public var contentHash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine(serverId)
        hasher.combine(type)
        hasher.combine(customization)
        hasher.combine(action)
        hasher.combine(tapAction)
        hasher.combine(displayText)
        hasher.combine(assistPrompt)
        hasher.combine(assistPipelineId)
        hasher.combine(items?.map(\.contentHash))
        return hasher.finalize()
    }

    /// True for items the watch only displays — a sensor entity, whose row opens a details screen
    /// instead of running anything. Nothing else about the item (colors, name, icon) differs.
    public var isWatchDisplayOnly: Bool {
        type == .entity && domain?.isWatchDisplayOnly == true
    }

    /// True for the item types that start an Assist session (a pipeline, or a written prompt) rather
    /// than calling a service.
    public var isAssist: Bool {
        type == .assistPipeline || type == .assistPrompt
    }

    /// Domain retrieved from id when item is entity else nil
    public var domain: Domain? {
        if let domainString = id.split(separator: ".").first, let domain = Domain(rawValue: String(domainString)) {
            return domain
        } else {
            return nil
        }
    }

    public init(
        id: String,
        serverId: String,
        type: ItemType,
        customization: Customization? = .init(),
        action: ItemAction? = .default,
        tapAction: ItemAction? = .default,
        displayText: String? = nil,
        assistPrompt: String? = nil,
        assistPipelineId: String? = nil,
        items: [MagicItem]? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.type = type
        self.customization = customization
        self.action = action
        self.tapAction = tapAction
        self.displayText = displayText
        self.assistPrompt = assistPrompt
        self.assistPipelineId = assistPipelineId
        self.items = items
    }

    public enum ItemType: String, Codable {
        case script
        case scene
        case entity
        case folder
        /// An entry that opens one area's entities. `id` is the area id and `serverId` the server it
        /// belongs to, so `serverUniqueId` matches `AppArea.id`. It holds no children — the area's
        /// entities are resolved live when the screen opens.
        case area
        case assistPipeline
        case assistPrompt
        /// An existing watch complication, rendered inline in the watch's item list. `id` is the
        /// `WatchComplicationConfig` id (a UUID), not an entity id.
        case complication
        case unsupported

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = Self(rawValue: rawValue) ?? .unsupported
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    public struct Customization: Codable, Equatable, Hashable {
        public var iconColor: String?
        public var textColor: String?
        public var backgroundColor: String?
        /// If true, execution will request confirmation before running
        public var requiresConfirmation: Bool
        /// Override icon, MaterialDesignIcons name
        public var icon: String?
        /// True only when the user explicitly picked a custom icon via the icon picker
        public var iconIsCustomized: Bool?
        /// True only when the user explicitly picked a custom icon color via the color picker
        public var iconColorIsCustomized: Bool?

        public var useCustomColors: Bool {
            textColor != nil || backgroundColor != nil
        }

        /// The icon color the user deliberately chose, or `nil` to let the entity keep the color
        /// home-assistant/frontend gives it.
        ///
        /// The customization screen seeds its color picker with the app's tint the first time it
        /// opens, so a stored color on its own never meant the user picked one. Items saved before
        /// ``iconColorIsCustomized`` existed are therefore only treated as customized when their
        /// color differs from that seed.
        public var customIconColor: String? {
            guard let iconColor else { return nil }
            if iconColorIsCustomized == true { return iconColor }
            return normalizedHex(iconColor) == normalizedHex(MagicItem.defaultIconColorHex)
                ? nil
                : iconColor
        }

        /// Uppercased six-digit hex, so the seed comparison isn't thrown off by a `#` prefix or an
        /// opaque alpha channel — the app writes the same color in both shapes.
        private func normalizedHex(_ hex: String) -> String {
            var normalized = hex.uppercased().replacingOccurrences(of: "#", with: "")
            if normalized.count == 8, normalized.hasSuffix("FF") {
                normalized = String(normalized.dropLast(2))
            }
            return normalized
        }

        public init(
            iconColor: String? = nil,
            textColor: String? = nil,
            backgroundColor: String? = nil,
            requiresConfirmation: Bool = false,
            icon: String? = nil,
            iconIsCustomized: Bool = false,
            iconColorIsCustomized: Bool = false
        ) {
            self.iconColor = iconColor
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.requiresConfirmation = requiresConfirmation
            self.icon = icon
            self.iconIsCustomized = iconIsCustomized
            self.iconColorIsCustomized = iconColorIsCustomized
        }
    }

    public struct Info: WatchCodable, Equatable {
        /// Server unique ID - "\(serverId)-(entityId)"
        public let id: String
        public let name: String
        public let iconName: String
        public let customization: Customization?
        /// Optional secondary "context" line shown under the name on configuration screens
        /// (`[Server • ]Area • Device`). `nil` when there's nothing meaningful to show, or for item
        /// types without entity context (folders, assist pipelines/prompts). Populated by
        /// `MagicItemProvider.getInfo`; not used when rendering the item itself on a widget/watch face.
        public let contextSubtitle: String?

        public init(
            id: String,
            name: String,
            iconName: String,
            customization: Customization? = nil,
            contextSubtitle: String? = nil
        ) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.customization = customization
            self.contextSubtitle = contextSubtitle
        }
    }

    /// Icon for given magic item type
    public func icon(info: Info) -> MaterialDesignIcons {
        var icon: MaterialDesignIcons
        if let icon = customization?.icon {
            return MaterialDesignIcons(named: icon, fallback: .dotsGridIcon)
        } else {
            switch type {
            case .scene:
                icon = MaterialDesignIcons(named: info.iconName, fallback: .scriptTextOutlineIcon)
            case .script, .entity:
                icon = MaterialDesignIcons(
                    serversideValueNamed: info.iconName,
                    fallback: .dotsGridIcon
                )
            case .folder:
                icon = .folderIcon
            case .area:
                icon = MaterialDesignIcons(
                    serversideValueNamed: info.iconName,
                    fallback: .textureBoxIcon
                )
            case .complication:
                icon = MaterialDesignIcons(serversideValueNamed: info.iconName, fallback: .watchIcon)
            case .assistPipeline:
                icon = .microphoneIcon
            case .assistPrompt:
                icon = .messageProcessingOutlineIcon
            case .unsupported:
                icon = .dotsGridIcon
            }
        }

        return icon
    }

    /// Name to be visible when rendegin item, priority: displayText -> info.name
    public func name(info: Info) -> String {
        displayText ?? info.name
    }

    /// Whether "toggle" can do anything for this item: it stands for an entity whose domain has
    /// the on/off service pair the frontend's `canToggleDomain` looks for. The frontend's action
    /// editor drops "toggle" from its list otherwise, and so does the customization screen.
    ///
    /// Without the entity's `supported_features` this is the domain-level answer; pass them to
    /// get the frontend's `canToggleState`, which also asks a climate, cover, camera, media
    /// player, or siren whether it supports turning on and off at all.
    public var canToggle: Bool {
        canToggle(supportedFeatures: nil)
    }

    public func canToggle(supportedFeatures: Int?) -> Bool {
        hasMoreInfoDialog && domain?.canToggle(supportedFeatures: supportedFeatures) == true
    }

    /// Whether the explicit on/off behaviors — "Lock" and "Unlock", "Open" and "Close", "Turn on"
    /// and "Turn off" — mean anything for this item: it toggles, and between two different
    /// services. A button or a scene has only the one, and "toggle" already runs it.
    public var hasOnOffActions: Bool {
        hasOnOffActions(supportedFeatures: nil)
    }

    public func hasOnOffActions(supportedFeatures: Int?) -> Bool {
        canToggle(supportedFeatures: supportedFeatures) && domain?.toggleIsStateAware == true
    }

    /// Whether the item's domain has a main action worth its own entry — "Press" for a button,
    /// "Activate" for a scene, "Run" for a script, "Trigger" for an automation — rather than one
    /// "Toggle" already names. See `Domain.explicitMainAction`.
    public var hasExplicitMainAction: Bool {
        hasMoreInfoDialog && domain?.explicitMainAction != nil
    }

    /// What `.default` stands for on a widget tile's icon, and on an app icon shortcut: for every
    /// `Domain.isActionable` domain the domain's own action — its main action where it names one
    /// ("Press", "Activate", "Run", "Trigger"), its toggle otherwise, which covers the
    /// state-aware pairs so a locked lock unlocks and a closed cover opens. Every other entity
    /// only opens: its more-info dialog, or the native camera player for a camera. An Assist
    /// pipeline starts Assist.
    public var defaultIconAction: ItemAction {
        if type == .assistPipeline {
            return .assist(serverId, assistPipelineId ?? id, true)
        }
        guard hasMoreInfoDialog, let domain, domain.isActionable else {
            return .moreInfoDialog
        }
        return domain.explicitMainAction != nil ? .mainAction : .toggle
    }

    /// What `.default` stands for on the rest of a widget tile: the entity's more-info dialog, the
    /// frontend tile card's `tap_action`. Items with no entity behind them — an Assist pipeline, a
    /// folder — have no dialog to open, so the whole tile keeps what the icon does.
    public var defaultTapAction: ItemAction {
        hasMoreInfoDialog ? .moreInfoDialog : defaultIconAction
    }

    /// What tapping a widget tile's icon — or the item's app icon shortcut — does.
    ///
    /// An explicit action override wins over whatever the item would do by default; a pipeline is
    /// the one item with nothing to override, since starting it is all it can do. The default is
    /// resolved through the same action the customization screen names as "Default", so what the
    /// picker says and what a tap does can't drift apart.
    public var widgetInteractionType: WidgetInteractionType {
        if type != .assistPipeline, let action, let interaction = interactionType(for: action) {
            return interaction
        }
        return interactionType(for: defaultIconAction) ?? .appIntent(.refresh)
    }

    /// What tapping a widget tile outside its icon does.
    ///
    /// Mirrors the frontend's tile card: the icon carries the entity's control and the rest of the
    /// card opens the entity. Items with no entity behind them — an Assist pipeline or prompt, a
    /// folder — have no more-info dialog to open, so the whole tile keeps the icon's action.
    public var widgetTapInteractionType: WidgetInteractionType {
        if let tapAction, let interaction = interactionType(for: tapAction) {
            return interaction
        }
        return hasMoreInfoDialog ? openEntityIntent() : widgetInteractionType
    }

    /// Whether tapping the item's icon on a widget controls the entity where it stands, rather than
    /// opening the app. Tiles that only open the app draw their icon without a background, the way
    /// the frontend leaves an uncontrollable entity's icon plain.
    public var controlsEntityFromWidget: Bool {
        switch widgetInteractionType {
        case .widgetURL:
            return false
        case let .appIntent(intentType):
            return intentType != .refresh
        }
    }

    /// Whether the item stands for an entity, and so has a more-info dialog to open.
    public var hasMoreInfoDialog: Bool {
        [.entity, .script, .scene].contains(type)
    }

    /// The interaction an explicitly chosen action performs. `nil` for `.default`, for a
    /// `.toggle` or an on/off behavior the item's domain can't perform, and for a more-info dialog
    /// an item without an entity can't open — all of which leave the choice to whatever the caller
    /// falls back on. The retired `.nothing` opens the more-info dialog: an icon that was told to
    /// do nothing must not start controlling the entity after an update.
    private func interactionType(for action: ItemAction) -> WidgetInteractionType? {
        switch action {
        case .default:
            return nil
        case .moreInfoDialog, .nothing:
            return hasMoreInfoDialog ? openEntityIntent() : nil
        case .toggle:
            return toggleIntent()
        case .mainAction:
            return mainActionIntent()
        case .turnOn:
            return onOffIntent(turnOn: true)
        case .turnOff:
            return onOffIntent(turnOn: false)
        case let .navigate(path):
            return navigateIntent(path: path)
        case let .url(urlString):
            return urlIntent(urlString)
        case let .performAction(serverId, actionId, payload):
            return .appIntent(.performAction(
                serverId: serverId,
                actionId: actionId,
                payload: payload
            ))
        case let .runScript(serverId, scriptId):
            return .appIntent(.activate(
                entityId: scriptId,
                domain: Domain.script.rawValue,
                serverId: serverId
            ))
        case let .assist(serverId, pipelineId, startListening):
            return assistIntent(
                serverId: serverId,
                pipelineId: pipelineId,
                startListening: startListening
            )
        }
    }

    /// The intent that toggles the entity the way the frontend does — turning a light on or off by
    /// its state, pressing a button, activating a scene, locking or unlocking a lock. `nil` for a
    /// domain with nothing to toggle between (a sensor).
    private func toggleIntent() -> WidgetInteractionType? {
        guard canToggle, let domain else { return nil }
        return .appIntent(.toggle(entityId: id, domain: domain.rawValue, serverId: serverId))
    }

    /// The intent that runs the domain's main action outright — pressing a button, activating a
    /// scene, running a script, triggering an automation. `nil` for a domain whose main action
    /// "Toggle" already covers, or that has none.
    private func mainActionIntent() -> WidgetInteractionType? {
        guard hasExplicitMainAction, let domain else { return nil }
        return .appIntent(.activate(entityId: id, domain: domain.rawValue, serverId: serverId))
    }

    /// The intent that calls one side of the entity's on/off pair outright — `lock.lock`,
    /// `cover.open_cover` — which is a "perform action" on the entity and nothing more.
    private func onOffIntent(turnOn: Bool) -> WidgetInteractionType? {
        guard hasOnOffActions, let domain, let services = domain.toggleServices else { return nil }
        let service = turnOn ? services.on : services.off
        return .appIntent(.performAction(
            serverId: serverId,
            actionId: "\(domain.serviceDomain).\(service.rawValue)",
            payload: "{\"entity_id\": \"\(id)\"}"
        ))
    }

    /// Opens whatever the user typed. Nothing to open — an empty or unusable address — leaves the
    /// tile refreshing rather than pointing nowhere.
    private func urlIntent(_ urlString: String) -> WidgetInteractionType {
        guard let url = ItemAction.resolvedURL(from: urlString) else {
            return .appIntent(.refresh)
        }
        return .widgetURL(url)
    }

    /// Opens this item's entity where tapping it lands: the native camera player for a camera,
    /// its more-info dialog in the app's web view for everything else.
    private func openEntityIntent() -> WidgetInteractionType {
        navigateIntent(url: AppConstants.openEntityDestinationURL(
            entityId: id,
            serverId: serverId
        ))
    }

    private func navigateIntent(path: String) -> WidgetInteractionType {
        let magicItem = self
        var path = path
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        if let url = AppConstants.navigateDeeplinkURL(
            path: path,
            serverId: magicItem.serverId,
            avoidUnnecessaryReload: true
        ) {
            return .widgetURL(url)
        } else {
            return .appIntent(.refresh)
        }
    }

    private func navigateIntent(url: URL?) -> WidgetInteractionType {
        guard let url else {
            return .appIntent(.refresh)
        }
        return .widgetURL(url)
    }

    private func assistIntent(serverId: String, pipelineId: String, startListening: Bool) -> WidgetInteractionType {
        if let url = AppConstants.assistDeeplinkURL(
            serverId: serverId,
            pipelineId: pipelineId,
            startListening: startListening
        ) {
            return .widgetURL(url)
        } else {
            return .appIntent(.refresh)
        }
    }
}

public enum MagicItemError: Error {
    case unknownDomain
}

/// What tapping a magic item runs, mirroring the tap actions the frontend's tile card offers.
///
/// Every case is persisted through `MagicItem`'s `Codable` conformance, so the case names and the
/// order of their associated values are storage format — renaming either drops existing
/// configurations back to `.default`.
public enum ItemAction: Codable, CaseIterable, Equatable, Hashable {
    /// Listed in the frontend's own order, with the app's own additions next to the action they
    /// resemble most: the domain's main action and on/off behaviors after "toggle", `runScript`
    /// after "perform action". The frontend's "no action" is left out: an item with nothing else
    /// to do opens its more-info dialog, so `.nothing` is storage only.
    public static var allCases: [ItemAction] = [
        .default,
        .moreInfoDialog,
        .toggle,
        .mainAction,
        .turnOn,
        .turnOff,
        .navigate(""),
        .url(""),
        .performAction("", "", ""),
        .runScript("", ""),
        .assist("", "", false),
    ]

    case `default`
    case moreInfoDialog
    /// The frontend's "toggle": the domain's on or off service, picked from the entity's state —
    /// `light.turn_on` for a light that is off, `lock.unlock` for a locked lock, `button.press`
    /// for a button. Only domains with such a pair can do this — see `Domain.toggleServices` — so
    /// for anything else the item falls back to the behavior it would have had without an override.
    case toggle
    /// Runs the domain's main action outright — press a button, activate a scene, run a script,
    /// trigger an automation — named that way on the customization screen, and only offered where
    /// "Toggle" doesn't already spell the same thing out. See `Domain.explicitMainAction`.
    case mainAction
    /// Calls the domain's "on" service outright, whatever the entity's state: `lock.unlock`,
    /// `cover.open_cover`, `light.turn_on`. Named after that service on the customization screen
    /// ("Unlock", "Open", "Turn on"), and only offered where it differs from the "off" one.
    case turnOn
    /// Calls the domain's "off" service outright: `lock.lock`, `cover.close_cover`,
    /// `light.turn_off`. The counterpart of `turnOn`.
    case turnOff
    case navigate(_ navigationPath: String)
    /// Opens an arbitrary URL, the frontend's `url` action (`url_path`). An `https://` link opens in
    /// the browser; the app's own `homeassistant://` deep links are handled in-app.
    case url(_ url: String)
    /// Calls `domain.service` with a JSON payload — the frontend's `perform-action`. `actionId` is
    /// the `domain.service` pair, `payload` the JSON object sent as the action's data.
    case performAction(_ serverId: String, _ actionId: String, _ payload: String)
    case runScript(_ serverId: String, _ scriptId: String)
    case assist(_ serverId: String, _ pipelineId: String, _ startListening: Bool)
    /// Retired: the picker no longer offers it, and an item stored with it opens the more-info
    /// dialog — the one behavior that, like doing nothing, never controls the entity. The case
    /// stays only so configurations saved while it was offered still decode — dropping it would
    /// fail every item in such a configuration, not just this one's choice.
    case nothing

    /// The behaviors a picker offers one item: every case, minus the ones the item's domain can't
    /// perform — "toggle" for an entity with nothing to toggle, the explicit on/off pair for one
    /// with a single service — the way the frontend's action editor filters "toggle" out of its
    /// own list. `supportedFeatures`, when known, narrows "toggle" the way the frontend's
    /// `canToggleState` does. A stored choice stays listed even then, so it never vanishes from
    /// under the user; it falls back at tap time the way it always has. The retired `.nothing` is
    /// the exception: it reads as "more info", so it is never listed.
    public static func offered(
        for item: MagicItem,
        supportedFeatures: Int? = nil,
        selected: ItemAction
    ) -> [ItemAction] {
        allCases.filter { itemAction in
            if itemAction.id == selected.id {
                return true
            }
            switch itemAction {
            case .toggle:
                return item.canToggle(supportedFeatures: supportedFeatures)
            case .mainAction:
                return item.hasExplicitMainAction
            case .turnOn, .turnOff:
                return item.hasOnOffActions(supportedFeatures: supportedFeatures)
            default:
                return true
            }
        }
    }

    /// Whether this is a stored choice the picker should show as "more info": the retired
    /// `.nothing`, which now behaves that way.
    public var isRetired: Bool {
        self == .nothing
    }

    public var id: String {
        switch self {
        case .default:
            return "default"
        case .moreInfoDialog:
            return "moreInfoDialog"
        case .toggle:
            return "toggle"
        case .mainAction:
            return "mainAction"
        case .turnOn:
            return "turnOn"
        case .turnOff:
            return "turnOff"
        case .navigate:
            return "navigate"
        case .url:
            return "url"
        case .performAction:
            return "performAction"
        case .runScript:
            return "runScript"
        case .assist:
            return "assist"
        case .nothing:
            return "nothing"
        }
    }

    /// The picker's label for `.default`, naming what it stands in for — "Default (More info)",
    /// "Default (Toggle)" — the way the frontend's action editor labels its default entry.
    public static func defaultName(resolvingTo actionName: String) -> String {
        L10n.Widgets.Action.Name.defaultAction(actionName)
    }

    /// The name shown for this behavior on one item. The domain's own behaviors take its words —
    /// "Press" for a button, "Run" for a script, "Lock" and "Unlock" for a lock, "Open" and
    /// "Close" for a cover — and everything else reads the same on every item.
    public func name(for domain: Domain?) -> String {
        switch self {
        case .mainAction:
            return domain?.mainActionName ?? name
        case .turnOn:
            return domain?.toggleServices?.on.toggleActionName ?? name
        case .turnOff:
            return domain?.toggleServices?.off.toggleActionName ?? name
        default:
            return name
        }
    }

    public var name: String {
        switch self {
        case .default:
            return L10n.Widgets.Action.Name.default
        case .moreInfoDialog:
            return L10n.Widgets.Action.Name.moreInfoDialog
        case .toggle:
            return L10n.Widgets.Action.Name.toggle
        case .mainAction:
            return L10n.Widgets.Action.Name.mainAction
        case .turnOn:
            return L10n.Widgets.Action.Name.turnOn
        case .turnOff:
            return L10n.Widgets.Action.Name.turnOff
        case .navigate:
            return L10n.Widgets.Action.Name.navigate
        case .url:
            return L10n.Widgets.Action.Name.url
        case .performAction:
            return L10n.Widgets.Action.Name.performAction
        case .runScript:
            return L10n.Widgets.Action.Name.runScript
        case .assist:
            return L10n.Widgets.Action.Name.assist
        case .nothing:
            return L10n.Widgets.Action.Name.nothing
        }
    }

    /// The URL a `.url` action opens, `nil` when there is nothing to open.
    ///
    /// A typed address usually omits its scheme ("example.com/page") and nothing can open it
    /// without one, so the web's default is assumed rather than leaving the action dead.
    public static func resolvedURL(from urlString: String) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}

public extension MagicItem {
    /// The color the icon color picker seeds itself with when an item has none yet: the app's tint.
    static var defaultIconColorHex: String {
        Color.haPrimary.hex() ?? Color.brand50.hex() ?? ""
    }

    static var defaultAssistIconColorHex: String {
        defaultIconColorHex
    }

    /// Single entry point for executing a magic item.
    ///
    /// Behavior depends on the platform: watchOS cannot use HAKit's WebSocket transport — raw/stream
    /// sockets are denied by NECP policy on real watch devices (see Starscream #957 / Apple DTS thread
    /// 127232) — so it executes via the Home Assistant REST API over `URLSession`, which is the only
    /// networking watchOS reliably supports and which inherits our mTLS client-certificate handling.
    /// Every other platform executes through the existing `HomeAssistantAPI` paths: scripts and scenes
    /// via the webhook API (`CallService`) and entity/lock actions over the WebSocket connection.
    ///
    /// `currentItemState` is used only for the lock domain, since it can't be toggled.
    ///
    /// `onStep` narrates the run's progress (resolved service call, URL, token stage, request,
    /// TLS challenges) for the watch's verbose execution trace. Ignored on non-watch platforms.
    func execute(
        on server: Server,
        source: AppTriggerSource,
        currentItemState: String = "",
        onStep: ((String) -> Void)? = nil,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        #if os(watchOS)
        executeViaREST(on: server, currentItemState: currentItemState, onStep: onStep, completion: completion)
        #else
        executeViaWebSocket(
            on: server,
            source: source,
            currentItemState: currentItemState,
            completion: completion
        )
        #endif
    }

    #if !os(watchOS)
    private func executeViaWebSocket(
        on server: Server,
        source: AppTriggerSource,
        currentItemState: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // Fail fast (and audibly) when there's no usable connection — e.g. the watch can't resolve
        // an active URL because it isn't on the internal network and no external/cloud URL exists.
        // Previously this path returned without ever calling `completion`, which surfaced as a
        // silent failure (the caller's UI just timed out).
        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available while executing magic item \(id)")
            completion(false, ServerConnectionError.noActiveURL(server.info.name))
            return
        }

        do {
            let request: Promise<Void>? = try {
                switch type {
                case .script:
                    let domain = Domain.script.rawValue
                    let service = id.replacingOccurrences(of: "\(domain).", with: "")
                    return api.CallService(
                        domain: domain,
                        service: service,
                        serviceData: [:],
                        triggerSource: source,
                        shouldLog: true
                    )
                case .scene:
                    let domain = Domain.scene.rawValue
                    return api.CallService(
                        domain: domain,
                        service: Service.turnOn.rawValue,
                        serviceData: [
                            "entity_id": id,
                        ],
                        triggerSource: source,
                        shouldLog: true
                    )
                case .entity:
                    guard let domain else {
                        throw MagicItemError.unknownDomain
                    }
                    return executeActionForDomainType(
                        server: server,
                        domain: domain,
                        entityId: id,
                        state: currentItemState
                    )
                case .folder, .area, .complication, .assistPipeline, .assistPrompt, .unsupported:
                    // Folders, areas, complications and assist items don't execute direct actions
                    return nil
                }
            }()

            guard let request else {
                // Nothing to execute for this item type (e.g. folder) — treat as a no-op success.
                completion(true, nil)
                return
            }

            request.pipe(to: { result in
                switch result {
                case .fulfilled:
                    Current.Log.verbose("Success executing magic item \(id)")
                    completion(true, nil)
                case let .rejected(error):
                    Current.Log.error("Error while executing magic item \(id): \(error.localizedDescription)")
                    completion(false, error)
                }
            })
        } catch {
            Current.Log.error("Error while executing magic item (2): \(error.localizedDescription)")
            completion(false, error)
        }
    }

    private func executeActionForDomainType(
        server: Server,
        domain: Domain,
        entityId: String,
        state: String
    ) -> Promise<Void> {
        var request: HATypedRequest<HAResponseVoid>?

        // Lock requires state-aware action
        if domain == .lock {
            guard let state = Domain.State(rawValue: state) else { return .value }
            switch state {
            case .unlocking, .unlocked, .opening:
                request = .lockLock(entityId: entityId)
            case .locked, .locking:
                request = .unlockLock(entityId: entityId)
            default:
                break
            }
        } else {
            // Use domain's main action for all other domains
            request = .executeMainAction(domain: domain, entityId: entityId)
        }

        if let request, let connection = Current.api(for: server)?.connection {
            return connection.send(request).promise
                .map { _ in () }
        } else {
            return .value
        }
    }
    #endif

    #if os(watchOS)
    /// The Home Assistant `call_service` (domain / service / data) that running this item performs.
    private struct WatchServiceCall {
        let domain: String
        let service: String
        let data: [String: Any]
    }

    /// How long the run waits for a bearer token before failing. The refresh request has no
    /// watchdog of its own, and `TokenManager` caches the in-flight refresh promise — a refresh
    /// that never resolves (started by any earlier request) would otherwise hang every run
    /// silently, with `completion` never called.
    private static var tokenDeadline: TimeInterval { 10 }

    /// watchOS executes via the REST API — see `execute(on:source:currentItemState:completion:)`.
    /// The request reuses the server's mTLS-aware `URLSession` and bearer token (token refresh already
    /// works over `URLSession` on the watch), so no WebSocket is involved.
    private func executeViaREST(
        on server: Server,
        currentItemState: String,
        onStep: ((String) -> Void)?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let serviceCall: WatchServiceCall?
        do {
            serviceCall = try resolveServiceCall(currentItemState: currentItemState)
        } catch {
            Current.Log.error("Error resolving service for magic item \(id): \(error.localizedDescription)")
            completion(false, error)
            return
        }

        guard let serviceCall else {
            // Item types without a direct action (folder/assist) — treat as a no-op success.
            completion(true, nil)
            return
        }
        onStep?("Service call: \(serviceCall.domain).\(serviceCall.service)")
        if let onStep {
            probeDispatchPools(onStep: onStep)
        }

        // No Swift concurrency on this path: watchOS gives the cooperative pool a single thread,
        // and a starved pool left taps hanging before the request ever started. The synchronous
        // URL evaluation is equivalent — on watchOS the last-known network state is always current.
        guard let baseURL = server.activeURLUsingLastKnownNetworkState() else {
            Current.Log.error("No active URL while executing magic item \(id) on watch")
            completion(false, ServerConnectionError.noActiveURL(server.info.name))
            return
        }
        onStep?("URL: \(baseURL.absoluteString)")

        // Narrate the token stage: an expired token forces a refresh over REST, the least protected
        // leg of the run — so the trace should say up front whether that leg is in play.
        let expiration = server.info.token.expiration
        let now = Current.date()
        if expiration.addingTimeInterval(-60) > now {
            onStep?("Access token valid for another \(Int(expiration.timeIntervalSince(now)))s")
        } else {
            onStep?("Access token expired — refreshing over REST (reuses any refresh already in flight)…")
        }

        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
        let tokenStarted = Current.date()
        onStep?("Requesting bearer token (\(Int(Self.tokenDeadline))s deadline)…")

        let lock = NSLock()
        var settled = false
        // First caller wins; the loser is discarded so `completion` runs exactly once. A late token
        // still lands in the shared cache for the next run.
        func settleOnce(_ body: () -> Void) {
            lock.lock()
            let shouldRun = !settled
            settled = true
            lock.unlock()
            if shouldRun { body() }
        }

        // Deadline so a stuck refresh fails the run instead of silencing it. Main queue on purpose,
        // not PromiseKit's `after` — that fires on the GCD global pool, which is exactly what these
        // hangs starve, so a pool-based deadline never fired and the run hung with no trace. Main is
        // the one queue proven to stay serviced on watch hardware (same reasoning as the URLSession
        // callback fallback in `sendRESTServiceCall`).
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tokenDeadline) {
            settleOnce {
                onStep?(
                    "No token after \(Int(Self.tokenDeadline))s — giving up. The refresh appears " +
                        "stuck; it stays cached, so later runs will fail fast too until the app restarts."
                )
                Current.Log.error("Token deadline elapsed executing magic item \(self.id)")
                completion(false, WatchRESTExecutionError.tokenTimeout)
            }
        }

        tokenManager.bearerToken.done { token, _ in
            settleOnce {
                onStep?(String(
                    format: "Token ready in %.2fs",
                    Current.date().timeIntervalSince(tokenStarted)
                ))
                self.sendRESTServiceCall(
                    baseURL: baseURL,
                    server: server,
                    token: token,
                    serviceCall: serviceCall,
                    onStep: onStep,
                    completion: completion
                )
            }
        }.catch { error in
            settleOnce {
                onStep?("Token failed: \(error.localizedDescription)")
                Current.Log
                    .error("Token unavailable executing magic item \(self.id): \(error.localizedDescription)")
                completion(false, error)
            }
        }
    }

    /// Fires a no-op on each global-QoS queue and narrates when it ran. During past hangs the GCD
    /// worker pool was starved while the main queue stayed serviced, so these lines show — per QoS
    /// level — whether background dispatch is alive during this run. A probe line that never
    /// appears in the trace is itself the finding: that QoS level never got a worker thread.
    private func probeDispatchPools(onStep: @escaping (String) -> Void) {
        let started = Current.date()
        let levels: [(label: String, qos: DispatchQoS.QoSClass)] = [
            ("user-interactive", .userInteractive),
            ("user-initiated", .userInitiated),
            ("default", .default),
            ("utility", .utility),
            ("background", .background),
        ]
        for level in levels {
            DispatchQueue.global(qos: level.qos).async {
                let elapsed = Current.date().timeIntervalSince(started)
                onStep(String(format: "Probe: global %@ queue ran after %.2fs", level.label, elapsed))
            }
        }
    }

    /// Maps this item to the service call it performs, mirroring the WebSocket path. Returns nil for
    /// item types that don't map to a service (folder, assist, no-op lock state).
    private func resolveServiceCall(currentItemState: String) throws -> WatchServiceCall? {
        switch type {
        case .script:
            let domain = Domain.script.rawValue
            let service = id.replacingOccurrences(of: "\(domain).", with: "")
            return WatchServiceCall(domain: domain, service: service, data: [:])
        case .scene:
            return WatchServiceCall(
                domain: Domain.scene.rawValue,
                service: Service.turnOn.rawValue,
                data: ["entity_id": id]
            )
        case .entity:
            guard let domain else {
                throw MagicItemError.unknownDomain
            }
            if domain == .lock {
                // Lock is state-aware; without a known state the call would guess wrong, so fail
                // loudly instead of silently doing nothing (a nil here reads as a no-op success).
                guard let state = Domain.State(rawValue: currentItemState) else {
                    throw WatchRESTExecutionError.lockStateUnknown
                }
                switch state {
                case .unlocking, .unlocked, .opening:
                    return WatchServiceCall(
                        domain: Domain.lock.rawValue,
                        service: Service.lock.rawValue,
                        data: ["entity_id": id]
                    )
                case .locked, .locking:
                    return WatchServiceCall(
                        domain: Domain.lock.rawValue,
                        service: Service.unlock.rawValue,
                        data: ["entity_id": id]
                    )
                default:
                    throw WatchRESTExecutionError.lockStateUnknown
                }
            } else {
                guard let action = domain.mainAction else { return nil }
                return WatchServiceCall(
                    domain: domain.serviceDomain,
                    service: action.rawValue,
                    data: ["entity_id": id]
                )
            }
        case .folder, .area, .complication, .assistPipeline, .assistPrompt, .unsupported:
            return nil
        }
    }

    /// Request timeout, and how long past it the run waits before declaring the session dead:
    /// URLSession has been observed never calling the data task back on watch hardware, even past
    /// `timeoutInterval` — its delivery queue itself can be starved.
    private static var requestTimeout: TimeInterval { 15 }
    private static var sessionCallbackFallback: TimeInterval { requestTimeout + 2 }

    private func sendRESTServiceCall(
        baseURL: URL,
        server: Server,
        token: String,
        serviceCall: WatchServiceCall,
        onStep: ((String) -> Void)?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("services")
            .appendingPathComponent(serviceCall.domain)
            .appendingPathComponent(serviceCall.service)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Bound the wait so a dead route fails visibly instead of hanging the row for the default 60s
        // (the UI resets after ~4s, but the task would otherwise keep a session + tokens alive).
        request.timeoutInterval = Self.requestTimeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        // Surface (rather than silently drop) encoding failures before starting the request.
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: serviceCall.data, options: [])
        } catch {
            completion(false, error)
            return
        }

        Current.Log.info("Executing magic item \(id) via REST: POST \(url.absoluteString)")

        let lock = NSLock()
        var finished = false
        // First caller wins; the loser's work is discarded so `completion` runs exactly once.
        func finishOnce(_ body: () -> Void) {
            lock.lock()
            let shouldRun = !finished
            finished = true
            lock.unlock()
            if shouldRun { body() }
        }

        let started = Current.date()
        onStep?(
            "POST /api/services/\(serviceCall.domain)/\(serviceCall.service) " +
                "(\(Int(Self.requestTimeout))s timeout)…"
        )

        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server, onStep: onStep)
        let task = session.dataTask(with: request) { [session] data, response, error in
            // The session strongly retains its delegate until invalidated; do it once the task ends.
            defer { session.finishTasksAndInvalidate() }
            let elapsed = String(format: "%.2fs", Current.date().timeIntervalSince(started))
            finishOnce {
                if let error {
                    Current.Log
                        .error("REST execution of magic item \(self.id) failed: \(error.localizedDescription)")
                    onStep?("Request failed after \(elapsed): \(error.localizedDescription)")
                    completion(false, error)
                    return
                }

                guard let http = response as? HTTPURLResponse else {
                    onStep?("Non-HTTP response after \(elapsed)")
                    completion(false, WatchRESTExecutionError.invalidResponse)
                    return
                }

                onStep?("Response \(http.statusCode) after \(elapsed)")
                if (200 ..< 300).contains(http.statusCode) {
                    Current.Log.verbose("Success executing magic item \(self.id) via REST")
                    completion(true, nil)
                } else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) }
                    Current.Log.error(
                        "REST execution of magic item \(self.id) returned \(http.statusCode): \(body ?? "<no body>")"
                    )
                    // The server rejected a token the client still considered valid; invalidate it
                    // so the next run refreshes instead of re-sending it — repeats get logged as
                    // invalid auth server-side and eventually IP-ban the watch.
                    if http.statusCode == 401 {
                        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
                        tokenManager.handleAccessTokenRejected(token)
                    }
                    completion(false, WatchRESTExecutionError.httpStatus(http.statusCode, body: body))
                }
            }
        }
        task.resume()
        // Fallback for a URLSession that never calls back — not even with its timeout error. Main
        // queue on purpose: it is the one queue proven to stay serviced on watch hardware (the GCD
        // global and Swift-concurrency pools have both been observed starved there).
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sessionCallbackFallback) {
            finishOnce {
                Current.Log.error("REST execution of magic item \(self.id) got no URLSession callback")
                onStep?(
                    "No answer from URLSession after \(Int(Self.sessionCallbackFallback))s — treating as " +
                        "failed. Either the network went silent past its own timeout, or the callback " +
                        "queue is starved and couldn't deliver the result."
                )
                session.invalidateAndCancel()
                completion(false, WatchRESTExecutionError.noURLSessionCallback)
            }
        }
    }

    private enum WatchRESTExecutionError: LocalizedError {
        case invalidResponse
        case httpStatus(_ statusCode: Int, body: String?)
        /// No bearer token within `tokenDeadline` — a token refresh is most likely stuck.
        case tokenTimeout
        /// URLSession never called the data task back, not even past `timeoutInterval`.
        case noURLSessionCallback
        /// The lock's current state hasn't been fetched (or isn't actionable, e.g. jammed).
        case lockStateUnknown

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return L10n.Watch.Home.Run.Error.message
            case let .httpStatus(_, body):
                // Home Assistant returns a human-readable message on failure; surface it when present.
                if let body, !body.isEmpty {
                    return body
                }
                return L10n.Watch.Home.Run.Error.message
            case .tokenTimeout:
                return L10n.Watch.Home.Run.Error.tokenTimeout
            case .noURLSessionCallback:
                return L10n.Watch.Home.Run.Error.noResponse
            case .lockStateUnknown:
                return L10n.Watch.Home.Run.Error.lockStateUnknown
            }
        }
    }
    #endif
}
