import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct EntityConfigurationWebView: View {
    @Environment(\.dismiss) private var dismiss
    let haEntity: HAEntity
    let server: Server
    let areaName: String?

    @State private var webView: WebViewController?

    var body: some View {
        NavigationStack {
            VStack {
                if let webView {
                    embed(webView)
                }
            }
            .navigationTitle(haEntity.attributes.friendlyName ?? haEntity.entityId)
            .navigationSubtitle(areaName ?? "")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadWebView()
            }
            .onDisappear {
                webView = nil
            }
        }
    }

    private func loadWebView() {
        guard let webViewURL = server.info.connection.webviewURL() else { return }
        let newWebView = WebViewController(server: server)
        webView = newWebView
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            webView?.load(request: .init(url: webViewURL.appending(queryItems: [.init(
                name: AppConstants.QueryItems.openMoreInfoDialog.rawValue,
                value: haEntity.entityId
            )])))
        }
    }
}
