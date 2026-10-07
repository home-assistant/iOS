import AppIntents
import Foundation
import Shared

/// One of the Focus names the user created in the app, offered as the choice in the Focus Filter
/// configuration iOS shows under Settings › Focus.
struct FocusNameAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.focus_filter.entity.name",
        defaultValue: "Focus name"
    ))
    static let defaultQuery = FocusNameAppEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init(stringLiteral: name))
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(focusName: FocusName) {
        self.init(id: focusName.id, name: focusName.name)
    }
}
