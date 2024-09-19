import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenPageItem {
    let page: PageAppEntity
    let icon: SFSymbolEntity
}

@available(iOS 18, *)
struct ControlOpenPageValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenPageConfiguration) async throws -> ControlOpenPageItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenPageConfiguration) -> ControlOpenPageItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenPageConfiguration) -> ControlOpenPageItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenPageConfiguration) -> ControlOpenPageItem {
        .init(
            page: configuration.page ?? placeholder().page,
            icon: configuration.icon ?? placeholder().icon
        )
    }

    private func placeholder() -> ControlOpenPageItem {
        .init(
            page: .init(
                id: UUID().uuidString,
                panel: .init(
                    icon: SFSymbol.rectangleAndPaperclip.rawValue,
                    title: L10n.Widgets.Controls.OpenPage.Configuration.Parameter.choosePage,
                    path: "",
                    component: "",
                    showInSidebar: false
                ),
                serverId: UUID().uuidString
            ),
            icon: .init(id: SFSymbol.rectangleAndPaperclip.rawValue)
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenPageConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_page.configuration.title",
        defaultValue: "Page"
    )

    @Parameter(
        title: .init("widgets.controls.open_page.configuration.parameter.page", defaultValue: "Page")
    )
    var page: PageAppEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?
}
