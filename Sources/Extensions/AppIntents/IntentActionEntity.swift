import AppIntents
import HAKit
import HAKit_PromiseKit
import PromiseKit
import SFSafeSymbols
import Shared
import UIKit

@available(iOS 17.0, *)
struct IntentActionEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
    static let defaultQuery = IntentActionEntityQuery()

    let id: String
    let serverId: String
    let actionId: String
    let displayName: String
    let actionDescription: String?
    let translationKey: String?
    let icon: String?
    /// Whether the underlying action returns a response (`SupportsResponse.OPTIONAL` / `.ONLY`).
    let supportsResponse: Bool

    var displayRepresentation: DisplayRepresentation {
        .init(
            title: .init(stringLiteral: displayName),
            subtitle: .init(stringLiteral: subtitle),
            image: displayRepresentationImage
        )
    }

    private var subtitle: String {
        [actionId, actionDescription]
            .compactMap { $0?.nilIfEmpty }
            .joined(separator: " - ")
    }

    private var displayRepresentationImage: DisplayRepresentation.Image {
        guard let data = icon?.materialDesignIconData else {
            return .init(systemName: SFSymbol.bolt.rawValue)
        }
        return .init(data: data, isTemplate: true)
    }
}

@available(iOS 17.0, *)
struct IntentActionEntityQuery: EntityQuery, EntityStringQuery {
    @IntentParameterDependency<PerformActionAppIntent>(\.$server)
    var intent

    func entities(for identifiers: [String]) async throws -> [IntentActionEntity] {
        let actions = try await actionEntities().flatMap(\.1)
        let matchedActions = actions.filter { identifiers.contains($0.id) }
        let matchedIdentifiers = Set(matchedActions.map(\.id))
        let fallbackActions = identifiers
            .filter { matchedIdentifiers.contains($0) == false }
            .compactMap(Self.actionEntity(for:))
        return matchedActions + fallbackActions
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentActionEntity> {
        try await actionCollection(matching: string)
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentActionEntity> {
        try await actionCollection()
    }

    private func actionCollection(matching string: String? = nil) async throws
        -> IntentItemCollection<IntentActionEntity> {
        let sections = try await actionEntities().map { server, actions in
            let filteredActions: [IntentActionEntity]
            if let string, string.isEmpty == false {
                filteredActions = actions.filter {
                    $0.displayName.localizedCaseInsensitiveContains(string)
                        || $0.actionId.localizedCaseInsensitiveContains(string)
                        || $0.translationKey?.localizedCaseInsensitiveContains(string) == true
                }
            } else {
                filteredActions = actions
            }
            return IntentItemSection<IntentActionEntity>(
                .init(stringLiteral: server.info.name),
                items: filteredActions
            )
        }
        return .init(sections: sections)
    }

    private func actionEntities() async throws -> [(Server, [IntentActionEntity])] {
        guard let server = intent?.server.getServer(),
              let connection = Current.api(for: server)?.connection else {
            return []
        }

        let definitions = try await connection.actionDefinitions().async(timeout: 10)
        return [(
            server,
            definitions.map { definition in
                Self.actionEntity(server: server, definition: definition)
            }
        )]
    }

    private static func actionEntity(server: Server, definition: IntentActionDefinition) -> IntentActionEntity {
        IntentActionEntity(
            id: "\(server.identifier.rawValue)::\(definition.actionId)",
            serverId: server.identifier.rawValue,
            actionId: definition.actionId,
            displayName: definition.displayName,
            actionDescription: definition.displayDescription,
            translationKey: definition.translationKey,
            icon: definition.icon,
            supportsResponse: definition.supportsResponse
        )
    }

    private static func actionEntity(for identifier: String) -> IntentActionEntity? {
        let components = identifier.components(separatedBy: "::")
        guard components.count == 2 else {
            return nil
        }

        return IntentActionEntity(
            id: identifier,
            serverId: components[0],
            actionId: components[1],
            displayName: components[1],
            actionDescription: nil,
            translationKey: nil,
            icon: nil,
            supportsResponse: false
        )
    }
}

private struct IntentActionDefinition {
    let domain: String
    let service: String
    let actionId: String
    let name: String?
    let description: String?
    let descriptionPlaceholders: [String: String]
    let translationKey: String?
    let icon: String?
    let supportsResponse: Bool
    let translations: [String: String]

    var displayName: String {
        localizedName ?? name?.nilIfEmptyUnlessTranslationKey ?? service
    }

    var displayDescription: String? {
        localizedDescription ?? description?.nilIfEmptyUnlessTranslationKey
    }

    private var localizedName: String? {
        localizedString(for: "component.\(domain).services.\(service).name")
    }

    private var localizedDescription: String? {
        localizedString(for: "component.\(domain).services.\(service).description")
    }

    private func localizedString(for key: String) -> String? {
        translations[key]?.applying(placeholders: descriptionPlaceholders).nilIfEmpty
    }
}

private extension HAConnection {
    typealias IntentActionServiceIcons = [String: [String: String]]
    typealias IntentActionServiceTranslations = [String: String]

    func actionDefinitions() -> Promise<[IntentActionDefinition]> {
        when(
            fulfilled:
            send(HARequest(type: .getServices)).promise,
            serviceIcons(),
            serviceTranslations()
        )
        .map { data, icons, translations in
            guard case let .dictionary(rawDictionary) = data,
                  let dictionary = rawDictionary as? [String: [String: [String: Any]]] else {
                return []
            }

            return dictionary.flatMap { domain, services in
                services.map { service, metadata in
                    let actionId = "\(domain).\(service)"
                    return IntentActionDefinition(
                        domain: domain,
                        service: service,
                        actionId: actionId,
                        name: metadata["name"] as? String,
                        description: metadata["description"] as? String,
                        descriptionPlaceholders: Self.stringDictionary(from: metadata["description_placeholders"]),
                        translationKey: metadata["translation_key"] as? String,
                        icon: icons[domain]?[service] ?? metadata["icon"] as? String,
                        supportsResponse: metadata["response"] is [String: Any],
                        translations: translations
                    )
                }
            }
            .sorted { first, second in
                first.actionId.localizedCaseInsensitiveCompare(second.actionId) == .orderedAscending
            }
        }
    }

    func serviceIcons() -> Promise<IntentActionServiceIcons> {
        send(HARequest(type: .webSocket("frontend/get_icons"), data: [
            "category": "services",
        ]))
        .promise
        .map { data in
            guard case let .dictionary(rawDictionary) = data,
                  let resources = rawDictionary["resources"] as? [String: [String: [String: Any]]] else {
                return [:]
            }

            return resources.reduce(into: IntentActionServiceIcons()) { result, domain in
                result[domain.key] = domain.value.reduce(into: [String: String]()) { services, service in
                    services[service.key] = service.value["service"] as? String
                }
            }
        }
        .recover { _ -> Promise<IntentActionServiceIcons> in .value([:]) }
    }

    func serviceTranslations() -> Promise<IntentActionServiceTranslations> {
        frontendTranslationLanguage()
            .then { language -> Promise<IntentActionServiceTranslations> in
                self.serviceTranslations(language: language)
            }
            .recover { _ -> Promise<IntentActionServiceTranslations> in .value([:]) }
    }

    func frontendTranslationLanguage() -> Promise<String> {
        send(HARequest(type: .webSocket("frontend/get_user_data"), data: [
            "key": "language",
        ]))
        .promise
        .map { data in
            guard case let .dictionary(rawDictionary) = data,
                  let value = rawDictionary["value"] as? [String: Any],
                  let language = value["language"] as? String,
                  language.isEmpty == false else {
                return Locale.homeAssistantTranslationIdentifier
            }

            return language
        }
        .recover { _ -> Promise<String> in .value(Locale.homeAssistantTranslationIdentifier) }
    }

    func serviceTranslations(language: String) -> Promise<IntentActionServiceTranslations> {
        send(HARequest(type: .webSocket("frontend/get_translations"), data: [
            "language": language,
            "category": "services",
        ]))
        .promise
        .map { data in
            guard case let .dictionary(rawDictionary) = data,
                  let resources = rawDictionary["resources"] as? [String: Any] else {
                return [:]
            }

            return Self.stringDictionary(from: resources)
        }
    }

    private static func stringDictionary(from value: Any?) -> [String: String] {
        guard let dictionary = value as? [String: Any] else {
            return [:]
        }

        return dictionary.reduce(into: [String: String]()) { result, item in
            if let string = item.value as? String {
                result[item.key] = string
            } else {
                result[item.key] = String(describing: item.value)
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var nilIfEmptyUnlessTranslationKey: String? {
        guard let value = nilIfEmpty else {
            return nil
        }
        return value.hasPrefix("component.") || value.hasPrefix("component::") ? nil : value
    }

    func applying(placeholders: [String: String]) -> String {
        placeholders.reduce(self) { value, placeholder in
            value.replacingOccurrences(of: "{\(placeholder.key)}", with: placeholder.value)
        }
    }

    var materialDesignIconData: Data? {
        MDIIconRenderer.iconData(forServersideValue: self)
    }
}

private extension Locale {
    static var homeAssistantTranslationIdentifier: String {
        Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first?.replacingOccurrences(of: "_", with: "-")
            ?? Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    }
}

/// Renders Material Design Icons to PNG data for use in `DisplayRepresentation.Image`.
///
/// The same icons recur frequently across the action list, and resolving + rendering each one
/// is expensive (two linear scans over ~7k icons plus a graphics-context render), so results are
/// memoized by their raw server-side value. `NSCache` is used rather than a plain dictionary
/// because it is thread-safe (the framework may read `displayRepresentation` off the main thread)
/// and evicts entries under the memory pressure of the Intents extension.
private enum MDIIconRenderer {
    private static let cache = NSCache<NSString, NSData>()

    static func iconData(forServersideValue serversideValue: String) -> Data? {
        let key = serversideValue as NSString
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }

        guard let data = icon(for: serversideValue).flatMap(data(for:)) else {
            return nil
        }
        cache.setObject(data as NSData, forKey: key)
        return data
    }

    private static func icon(for serversideValue: String) -> MaterialDesignIcons? {
        let iconName = serversideValue.normalizingIconString
        guard MaterialDesignIcons.allCases.contains(where: { $0.name == iconName }) else {
            return nil
        }
        return MaterialDesignIcons(serversideValueNamed: serversideValue)
    }

    private static func data(for icon: MaterialDesignIcons) -> Data? {
        MaterialDesignIcons.register()

        let size = CGSize(width: 64, height: 64)
        let imageRect = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
        return UIGraphicsImageRenderer(size: size).pngData { _ in
            icon
                .image(ofSize: imageRect.size, color: .black)
                .draw(in: imageRect)
        }
    }
}
