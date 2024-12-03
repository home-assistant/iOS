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
        guard let page,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == page.serverId }) ?? Current
              .servers.all.first else { return .result() }

        let urlString = "/" + page.panel.path

        #if !WIDGET_EXTENSION
        DispatchQueue.main.async {
            if Current.isCatalyst, Current.settingsStore.macNativeFeaturesOnly {
                if let activeURL = server.info.connection.activeURL(),
                   let pageURL = URL(string: "\(activeURL)\(urlString)") {
                    UIApplication.shared.open(pageURL)
                } else {
                    Current.Log.error("Failed to open page \(urlString) on server \(server.info.name)")
                }
            } else {
                Current.sceneManager.webViewWindowControllerPromise.done { windowController in
                    windowController.open(
                        from: .deeplink,
                        server: server,
                        urlString: urlString,
                        skipConfirm: true
                    )
                }
            }
        }
        #endif
        return .result()
    }
}
