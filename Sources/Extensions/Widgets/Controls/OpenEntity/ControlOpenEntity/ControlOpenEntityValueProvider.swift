import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenEntityItem {
    let entity: HAAppEntityAppIntentEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenEntityValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenEntityConfiguration) async throws -> ControlOpenEntityItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenEntityConfiguration) -> ControlOpenEntityItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenEntityConfiguration) -> ControlOpenEntityItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenEntityConfiguration) -> ControlOpenEntityItem {
        .init(
            entity: configuration.entity ?? .init(
                id: "",
                entityId: "",
                serverId: "",
                serverName: "",
                displayString: "",
                iconName: ""
            ),
            icon: configuration.icon ?? placeholder().icon
        )
    }

    private func placeholder() -> ControlOpenEntityItem {
        .init(
            entity: .init(id: "", entityId: "", serverId: "", serverName: "", displayString: "", iconName: ""),
            icon: .init(id: SFSymbol.rectangleAndPaperclip.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenEntityConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_entity.configuration.title",
        defaultValue: "Open Entity"
    )

    @Parameter(
        title: .init("widgets.controls.open_entity.configuration.parameter.entity", defaultValue: "Entity")
    )
    var entity: HAAppEntityAppIntentEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}
