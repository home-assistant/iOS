import AppIntents
import Foundation
import Shared
import UIKit

/// Where "Add entity to" puts an entity.
///
/// These are the destinations the frontend's own "Add to" sheet offers (`EntityAddToActionType`),
/// narrowed to the three that are nothing but a config write. The widget builder, the NFC sheet and
/// the deep link share sheet all need someone at the screen to finish, so there is nothing for an
/// intent to complete on its own and they are deliberately absent.
@available(macOS 13.0, *)
enum EntityAddToDestinationAppEnum: String, Codable, Sendable, AppEnum {
    case appleWatch
    case carPlay
    case macToolbar

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.add_to.destination.name",
        defaultValue: "Destination"
    ))

    /// The same names the frontend's "Add to" sheet uses, so the two ways of adding an entity do not
    /// call the same place by two different names.
    static let caseDisplayRepresentations: [EntityAddToDestinationAppEnum: DisplayRepresentation] = [
        .appleWatch: .init(title: .init("web_view.add_to.option.AppleWatch.title", defaultValue: "Apple Watch")),
        .carPlay: .init(title: .init("web_view.add_to.option.CarPlay.title", defaultValue: "CarPlay")),
        .macToolbar: .init(title: .init("web_view.add_to.option.MacToolbar.title", defaultValue: "Mac Toolbar")),
    ]

    var localizedName: String {
        switch self {
        case .appleWatch: L10n.WebView.AddTo.Option.AppleWatch.title
        case .carPlay: L10n.WebView.AddTo.Option.CarPlay.title
        case .macToolbar: L10n.WebView.AddTo.Option.MacToolbar.title
        }
    }

    /// Whether this device has the destination at all, matching the offer `EntityAddToHandler` makes
    /// in the frontend's sheet: CarPlay quick access is an iPhone's, the Mac toolbar is Catalyst's
    /// alone, and a Mac never pairs with the watch the way a phone does.
    @MainActor
    var isAvailable: Bool {
        switch self {
        case .appleWatch:
            !Current.isCatalyst
        case .carPlay:
            !Current.isCatalyst && UIDevice.current.userInterfaceIdiom == .phone
        case .macToolbar:
            Current.isCatalyst
        }
    }

    /// Whether the destination can show this entity.
    ///
    /// The watch and CarPlay each render a fixed set of domains; the Mac toolbar puts every entity
    /// behind a more info dialog, so nothing is off limits there. A domain the app does not model at
    /// all fails everywhere, having no icon, no row and no dialog to open.
    func supports(entityId: String) -> Bool {
        guard let domain = Domain(entityId: entityId) else { return false }
        switch self {
        case .appleWatch: return Domain.watchAddable.contains(domain)
        case .carPlay: return Domain.carPlaySupported.contains(domain)
        case .macToolbar: return true
        }
    }
}
