import AppIntents
import Foundation

/// Which way to move a cover. Interpolated into the phrase, so one template covers both verbs.
@available(macOS 13.0, watchOS 9.4, *)
enum OpenCloseActionAppEnum: String, Codable, Sendable, AppEnum {
    case open
    case close

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.open_close.action.name",
        defaultValue: "Action"
    ))

    static let caseDisplayRepresentations: [OpenCloseActionAppEnum: DisplayRepresentation] = [
        .open: .init(title: .init("app_intents.open_close.action.open", defaultValue: "Open")),
        .close: .init(title: .init("app_intents.open_close.action.close", defaultValue: "Close")),
    ]
}
