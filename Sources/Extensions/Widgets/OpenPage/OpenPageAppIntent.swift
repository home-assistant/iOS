import AppIntents
import Foundation
import Shared
import SwiftUI

// AppIntent that open app needs to have it's target the widget extension AND app target!
@available(iOS 18, *)
struct OpenPageAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_page.configuration.title",
        defaultValue: "Open Page"
    )

    static var openAppWhenRun: Bool = true

    @Parameter(
        title: .init("widgets.controls.open_page.configuration.parameter.page", defaultValue: "Page")
    )
    var page: PageAppEntity?

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        guard let page,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == page.serverId }) ?? Current
              .servers.all.first else { return .result() }

        let urlString = "/" + page.panel.path
        Current.sceneManager.webViewWindowControllerPromise.done { windowController in
            windowController.open(
                from: .deeplink,
                server: server,
                urlString: urlString,
                skipConfirm: true
            )
        }
        #endif
        return .result()
    }
}
