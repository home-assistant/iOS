import AppIntents
import UIKit

@available(watchOS 10.0, *)
struct WatchWidgetComplicationEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Complication")
    static let defaultQuery = WatchWidgetComplicationEntityQuery()

    /// The Home Assistant logo rendered to PNG data. `DisplayRepresentation.Image(named:)` does not
    /// reliably resolve asset-catalog images in the AppIntents picker, so the logo is passed as data.
    private static let logoImageData: Data? = UIImage(named: WatchWidgetConstants.logoAssetName)?.pngData()

    let id: String
    let title: String
    let subtitle: String
    let iconData: Data?
    let kind: WatchWidgetComplicationKind

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: .init(stringLiteral: title),
            subtitle: .init(stringLiteral: subtitle),
            image: displayImage
        )
    }

    // Mirrors the on-face rendering (`WatchWidgetComplicationSnapshot`): user complications use their
    // carried icon, the placeholder uses the Home Assistant logo, and Assist uses its symbol.
    private var displayImage: DisplayRepresentation.Image {
        if kind == .user, let iconData {
            return .init(data: iconData, isTemplate: true)
        }
        switch kind {
        case .assist:
            return .init(systemName: WatchWidgetConstants.Symbol.assist)
        case .placeholder, .user:
            if let logoImageData = Self.logoImageData {
                return .init(data: logoImageData)
            }
            return .init(systemName: WatchWidgetConstants.Symbol.homeAssistant)
        }
    }

    init(snapshot: WatchWidgetComplicationSnapshot) {
        self.id = snapshot.recommendationID
        self.title = snapshot.recommendationTitle
        self.subtitle = snapshot.subtitle
        self.iconData = snapshot.iconData
        self.kind = WatchWidgetComplicationKind(snapshot: snapshot)
    }
}

@available(watchOS 10.0, *)
struct WatchWidgetComplicationEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [WatchWidgetComplicationEntity.ID]) async throws -> [WatchWidgetComplicationEntity] {
        entities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<WatchWidgetComplicationEntity> {
        let matchingEntities = entities().filter { entity in
            string.isEmpty
                || entity.title.localizedCaseInsensitiveContains(string)
                || entity.subtitle.localizedCaseInsensitiveContains(string)
        }
        return .init(items: matchingEntities)
    }

    func suggestedEntities() async throws -> IntentItemCollection<WatchWidgetComplicationEntity> {
        .init(items: entities())
    }

    func defaultResult() async -> WatchWidgetComplicationEntity? {
        WatchWidgetComplicationEntity(snapshot: .placeholder)
    }

    private func entities() -> [WatchWidgetComplicationEntity] {
        WatchWidgetComplicationSnapshotStore.recommendations().map(WatchWidgetComplicationEntity.init(snapshot:))
    }
}

@available(watchOS 10.0, *)
enum WatchWidgetComplicationKind: String, AppEnum, Sendable {
    case placeholder
    case assist
    case user

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Complication Type")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .placeholder: "Home Assistant",
        .assist: "Assist",
        .user: "Complication",
    ]

    init(snapshot: WatchWidgetComplicationSnapshot) {
        switch snapshot.recommendationID {
        case WatchWidgetComplicationSnapshot.placeholderID:
            self = .placeholder
        case WatchWidgetComplicationSnapshot.assistID:
            self = .assist
        default:
            self = .user
        }
    }
}
