import Foundation
import GRDB
import HAKit
import PromiseKit

/// Object that represents iOS item that can be displayed in Watch, Widgets, CarPlay and perform different action types
public struct MagicItem: Codable, Equatable, Hashable {
    public static func == (lhs: MagicItem, rhs: MagicItem) -> Bool {
        lhs.id == rhs.id && lhs.serverId == rhs.serverId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Id match it's type Id, e.g. "script.open_gate"
    public let id: String
    public var serverId: String
    public let type: ItemType
    public var customization: Customization?
    public var action: ItemAction?
    public var displayText: String?

    /// Server unique ID - e.g. "EB1364-script.open_gate"
    public var serverUniqueId: String {
        "\(serverId)-\(id)"
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
        displayText: String? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.type = type
        self.customization = customization
        self.action = action
        self.displayText = displayText
    }

    public enum ItemType: String, Codable {
        /// aka iOS legacy Action
        case action
        case script
        case scene
        case entity
    }

    public struct Customization: Codable, Equatable {
        public var iconColor: String?
        public var textColor: String?
        public var backgroundColor: String?
        /// If true, execution will request confirmation before running
        public var requiresConfirmation: Bool
        /// Override icon, MaterislDesignIcons name
        public var icon: String?

        public var useCustomColors: Bool {
            textColor != nil || backgroundColor != nil
        }

        public init(
            iconColor: String? = nil,
            textColor: String? = nil,
            backgroundColor: String? = nil,
            requiresConfirmation: Bool = false,
            icon: String? = nil
        ) {
            self.iconColor = iconColor
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.requiresConfirmation = requiresConfirmation
            self.icon = icon
        }
    }

    public struct Info: WatchCodable, Equatable {
        /// Server unique ID - "\(serverId)-(entityId)"
        public let id: String
        public let name: String
        public let iconName: String
        public let customization: Customization?

        public init(id: String, name: String, iconName: String, customization: Customization? = nil) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.customization = customization
        }
    }

    /// Icon for given magic item type
    public func icon(info: Info) -> MaterialDesignIcons {
        var icon: MaterialDesignIcons
        if let icon = customization?.icon {
            return MaterialDesignIcons(named: icon, fallback: .dotsGridIcon)
        } else {
            switch type {
            case .action, .scene:
                icon = MaterialDesignIcons(named: info.iconName, fallback: .scriptTextOutlineIcon)
            case .script, .entity:
                icon = MaterialDesignIcons(
                    serversideValueNamed: info.iconName,
                    fallback: .dotsGridIcon
                )
            }
        }

        return icon
    }

    /// Name to be visible when rendegin item, priority: displayText -> info.name
    public func name(info: Info) -> String {
        displayText ?? info.name
    }

    public var widgetIconInteractionType: WidgetInteractionType {
        let magicItem = self
        guard let domain = magicItem.domain else { return .appIntent(.refresh) }

        var interactionType: WidgetInteractionType = .appIntent(.refresh)

        if let magicItemAction = magicItem.action, magicItemAction != .default {
            switch magicItemAction {
            case .default:
                // This block of code should not be reached, default should not be handled here
                // Returning something to avoid compiler error
                interactionType = .appIntent(.refresh)
            case .moreInfoDialog:
                interactionType = navigateIntent(url: AppConstants.openEntityDeeplinkURL(
                    entityId: magicItem.id,
                    serverId: magicItem.serverId
                ))
            case .nothing:
                interactionType = .appIntent(.refresh)
            case let .navigate(path):
                interactionType = navigateIntent(path: path)
            case let .runScript(serverId, scriptId):
                interactionType = .appIntent(.activate(
                    entityId: scriptId,
                    domain: Domain.script.rawValue,
                    serverId: serverId
                ))
            case let .assist(serverId, pipelineId, startListening):
                interactionType = assistIntent(
                    serverId: serverId,
                    pipelineId: pipelineId,
                    startListening: startListening
                )
            }
        } else {
            switch domain {
            case .button, .inputButton:
                interactionType = .appIntent(.press(
                    entityId: magicItem.id,
                    domain: domain.rawValue,
                    serverId: magicItem.serverId
                ))
            case .cover, .inputBoolean, .light, .switch:
                interactionType = .appIntent(.toggle(
                    entityId: magicItem.id,
                    domain: domain.rawValue,
                    serverId: magicItem.serverId
                ))
            case .lock:
                interactionType = navigateIntent(url: AppConstants.openEntityDeeplinkURL(
                    entityId: magicItem.id,
                    serverId: magicItem.serverId
                ))
            case .scene, .script:
                interactionType = .appIntent(.activate(
                    entityId: magicItem.id,
                    domain: domain.rawValue,
                    serverId: magicItem.serverId
                ))
            default:
                interactionType = .appIntent(.refresh)
            }
        }

        return interactionType
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
            avoidUnecessaryReload: true
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

public enum ItemAction: Codable, CaseIterable, Equatable {
    public static var allCases: [ItemAction] = [
        .default,
        .moreInfoDialog,
        .navigate(""),
        .runScript("", ""),
        .assist("", "", false),
        .nothing,
    ]

    case `default`
    case moreInfoDialog
    case navigate(_ navigationPath: String)
    case runScript(_ serverId: String, _ scriptId: String)
    case assist(_ serverId: String, _ pipelineId: String, _ startListening: Bool)
    case nothing

    public var id: String {
        switch self {
        case .default:
            return "default"
        case .moreInfoDialog:
            return "moreInfoDialog"
        case .navigate:
            return "navigate"
        case .runScript:
            return "runScript"
        case .assist:
            return "assist"
        case .nothing:
            return "nothing"
        }
    }

    public var name: String {
        switch self {
        case .default:
            return L10n.Widgets.Action.Name.default
        case .moreInfoDialog:
            return L10n.Widgets.Action.Name.moreInfoDialog
        case .navigate:
            return L10n.Widgets.Action.Name.navigate
        case .runScript:
            return L10n.Widgets.Action.Name.runScript
        case .assist:
            return L10n.Widgets.Action.Name.assist
        case .nothing:
            return L10n.Widgets.Action.Name.nothing
        }
    }
}

public extension MagicItem {
    // currentItemState is used only for lock domain since it can't be toggled
    func execute(
        on server: Server,
        source: AppTriggerSource,
        currentItemState: String = "",
        completion: @escaping (Bool) -> Void
    ) {
        do {
            if let request: Promise<Void> = try {
                switch type {
                case .script:
                    let domain = Domain.script.rawValue
                    let service = id.replacingOccurrences(of: "\(domain).", with: "")
                    return Current.api(for: server)?.CallService(
                        domain: domain,
                        service: service,
                        serviceData: [:],
                        triggerSource: source,
                        shouldLog: true
                    )
                case .action:
                    return Current.api(for: server)?
                        .HandleAction(actionID: id, source: source)
                case .scene:
                    let domain = Domain.scene.rawValue
                    return Current.api(for: server)?.CallService(
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
                }
            }() {
                request.pipe(to: { result in
                    switch result {
                    case .fulfilled:
                        Current.Log.verbose("Success executing magic item \(id)")
                        completion(true)
                    case let .rejected(error):
                        Current.Log.error("Error while executing magic item \(id): \(error.localizedDescription)")
                        completion(false)
                    }
                })
            } else {
                Current.Log.error("No request available while executing magic item \(id)")
            }
        } catch {
            Current.Log.error("Error while executing magic item (2): \(error.localizedDescription)")
            completion(false)
        }
    }

    private func executeActionForDomainType(
        server: Server,
        domain: Domain,
        entityId: String,
        state: String
    ) -> Promise<Void> {
        var request: HATypedRequest<HAResponseVoid>?
        switch domain {
        case .button, .inputButton:
            request = .pressButton(domain: domain, entityId: entityId)
        case .cover, .inputBoolean, .light, .switch, .fan:
            request = .toggleDomain(domain: domain, entityId: entityId)
        case .scene:
            request = .applyScene(entityId: entityId)
        case .script:
            request = .runScript(entityId: entityId)
        case .lock:
            guard let state = Domain.State(rawValue: state) else { return .value }
            switch state {
            case .unlocking, .unlocked, .opening:
                request = .lockLock(entityId: entityId)
            case .locked, .locking:
                request = .unlockLock(entityId: entityId)
            default:
                break
            }
        case .sensor, .binarySensor, .zone, .person, .camera:
            break
        case .automation:
            request = .trigger(entityId: entityId)
        }
        if let request, let connection = Current.api(for: server)?.connection {
            return connection.send(request).promise
                .map { _ in () }
        } else {
            return .value
        }
    }
}
