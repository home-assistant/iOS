import Foundation
import GRDB
import HAKit
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
    public var action: ItemAction?
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
        hasher.combine(displayText)
        hasher.combine(assistPrompt)
        hasher.combine(assistPipelineId)
        hasher.combine(items?.map(\.contentHash))
        return hasher.finalize()
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
        case assistPipeline
        case assistPrompt
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

        public var useCustomColors: Bool {
            textColor != nil || backgroundColor != nil
        }

        public init(
            iconColor: String? = nil,
            textColor: String? = nil,
            backgroundColor: String? = nil,
            requiresConfirmation: Bool = false,
            icon: String? = nil,
            iconIsCustomized: Bool = false
        ) {
            self.iconColor = iconColor
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.requiresConfirmation = requiresConfirmation
            self.icon = icon
            self.iconIsCustomized = iconIsCustomized
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

    public var widgetInteractionType: WidgetInteractionType {
        let magicItem = self

        if magicItem.type == .assistPipeline {
            return assistIntent(
                serverId: magicItem.serverId,
                pipelineId: magicItem.assistPipelineId ?? magicItem.id,
                startListening: true
            )
        }

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
            case .climate:
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
                interactionType = navigateIntent(url: AppConstants.openEntityDeeplinkURL(
                    entityId: magicItem.id,
                    serverId: magicItem.serverId
                ))
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

public enum ItemAction: Codable, CaseIterable, Equatable, Hashable {
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
    static var defaultAssistIconColorHex: String {
        Color.haPrimary.hex() ?? Color.brand50.hex() ?? ""
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
    func execute(
        on server: Server,
        source: AppTriggerSource,
        currentItemState: String = "",
        completion: @escaping (Bool, Error?) -> Void
    ) {
        #if os(watchOS)
        executeViaREST(on: server, currentItemState: currentItemState, completion: completion)
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
                case .folder, .assistPipeline, .assistPrompt, .unsupported:
                    // Folders and assist items don't execute direct actions
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

    /// watchOS executes via the REST API — see `execute(on:source:currentItemState:completion:)`.
    /// The request reuses the server's mTLS-aware `URLSession` and bearer token (token refresh already
    /// works over `URLSession` on the watch), so no WebSocket is involved.
    private func executeViaREST(
        on server: Server,
        currentItemState: String,
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

        var connectionInfo = server.info.connection
        guard let baseURL = connectionInfo.activeURL() else {
            Current.Log.error("No active URL while executing magic item \(id) on watch")
            completion(false, ServerConnectionError.noActiveURL(server.info.name))
            return
        }

        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
        tokenManager.bearerToken.done { token, _ in
            self.sendRESTServiceCall(
                baseURL: baseURL,
                server: server,
                token: token,
                serviceCall: serviceCall,
                completion: completion
            )
        }.catch { error in
            Current.Log.error("Token unavailable executing magic item \(self.id): \(error.localizedDescription)")
            completion(false, error)
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
                guard let state = Domain.State(rawValue: currentItemState) else { return nil }
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
                    return nil
                }
            } else {
                guard let action = domain.mainAction else { return nil }
                return WatchServiceCall(domain: domain.rawValue, service: action.rawValue, data: ["entity_id": id])
            }
        case .folder, .assistPipeline, .assistPrompt, .unsupported:
            return nil
        }
    }

    private func sendRESTServiceCall(
        baseURL: URL,
        server: Server,
        token: String,
        serviceCall: WatchServiceCall,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("services")
            .appendingPathComponent(serviceCall.domain)
            .appendingPathComponent(serviceCall.service)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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

        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        let task = session.dataTask(with: request) { [session] data, response, error in
            // The session strongly retains its delegate until invalidated; do it once the task ends.
            defer { session.finishTasksAndInvalidate() }

            if let error {
                Current.Log.error("REST execution of magic item \(self.id) failed: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(false, WatchRESTExecutionError.invalidResponse)
                return
            }

            if (200 ..< 300).contains(http.statusCode) {
                Current.Log.verbose("Success executing magic item \(self.id) via REST")
                completion(true, nil)
            } else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) }
                Current.Log.error(
                    "REST execution of magic item \(self.id) returned \(http.statusCode): \(body ?? "<no body>")"
                )
                completion(false, WatchRESTExecutionError.httpStatus(http.statusCode, body: body))
            }
        }
        task.resume()
    }

    private enum WatchRESTExecutionError: LocalizedError {
        case invalidResponse
        case httpStatus(_ statusCode: Int, body: String?)

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
            }
        }
    }
    #endif
}
