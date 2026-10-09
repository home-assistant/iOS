import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18.0, *)
struct ControlCoverConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.cover.description",
        defaultValue: "Toggle cover"
    )

    @Parameter(
        title: .init(
            "app_intents.server.title",
            defaultValue: "Server"
        )
    )
    var server: IntentServerAppEntity?

    @Parameter(
        title: .init(
            "widgets.controls.cover.title",
            defaultValue: "Cover"
        )
    )
    var entity: IntentCoverEntity?

    @Parameter(
        title: .init(
            "app_intents.open_state_icon.title",
            defaultValue: "Icon for open state"
        ),
        default: SFSymbolEntity(id: SFSymbol.curtainsOpen.rawValue)
    )
    var openIcon: SFSymbolEntity?

    @Parameter(
        title: .init(
            "app_intents.closed_state_icon.title",
            defaultValue: "Icon for closed state"
        ),
        default: SFSymbolEntity(id: SFSymbol.curtainsClosed.rawValue)
    )
    var closedIcon: SFSymbolEntity?

    @Parameter(
        title: .init(
            "app_intents.display_text.title",
            defaultValue: "Display Text"
        )
    )
    var displayText: String?

    @Parameter(
        title: .init(
            "widgets.controls.cover.show_next_action",
            defaultValue: "Show next action"
        ),
        default: false
    )
    var showNextAction: Bool
}
