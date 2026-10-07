import Foundation

/// One Home Assistant action (`domain.service`) as offered to the "Perform action" App Intent.
///
/// The same shape is produced by both transports: the WebSocket build carries the frontend's icons
/// and translations, the REST build (watchOS) has neither available and leaves them empty — see
/// `AppIntentServerAPI.actionDefinitions(server:)`.
public struct IntentActionDefinition: Equatable {
    public let domain: String
    public let service: String
    public let name: String?
    public let actionDescription: String?
    public let descriptionPlaceholders: [String: String]
    public let translationKey: String?
    public let icon: String?
    /// Whether the action returns a response (`SupportsResponse.OPTIONAL` / `.ONLY`).
    public let supportsResponse: Bool
    /// Frontend translations for the current language, keyed by `component.<domain>.services.…`.
    public let translations: [String: String]

    public init(
        domain: String,
        service: String,
        name: String?,
        actionDescription: String?,
        descriptionPlaceholders: [String: String] = [:],
        translationKey: String? = nil,
        icon: String? = nil,
        supportsResponse: Bool = false,
        translations: [String: String] = [:]
    ) {
        self.domain = domain
        self.service = service
        self.name = name
        self.actionDescription = actionDescription
        self.descriptionPlaceholders = descriptionPlaceholders
        self.translationKey = translationKey
        self.icon = icon
        self.supportsResponse = supportsResponse
        self.translations = translations
    }

    public var actionId: String {
        "\(domain).\(service)"
    }

    public var displayName: String {
        localizedName ?? name?.nilIfEmptyUnlessTranslationKey ?? service
    }

    public var displayDescription: String? {
        localizedDescription ?? actionDescription?.nilIfEmptyUnlessTranslationKey
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
