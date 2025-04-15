import Foundation
import MBProgressHUD
import Shared

// MARK: - Gestures

extension WebViewController {
    func handleGestureAction(_ action: HAGestureAction) {
        switch action {
        case .showSidebar:
            showSidebar()
        case .backPage:
            webViewNavigateBack()
        case .nextPage:
            webViewNavigateForward()
        case .showServersList:
            showServersList()
        case .nextServer:
            moveToServer(next: true)
        case .previousServer:
            moveToServer(next: false)
        case .showSettings:
            showSettingsViewController()
        case .openDebug:
            openDebug()
        case .searchEntities:
            showSearchEntities()
        case .none:
            /* no-op */
            break
        }
    }

    private func showSidebar() {
        webViewExternalMessageHandler
            .sendExternalBus(message: .init(command: WebViewExternalBusMessage.showSidebar.rawValue))
    }

    private func webViewNavigateBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    private func webViewNavigateForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    private func showServersList() {
        Current.sceneManager.webViewWindowControllerPromise.done { controller in
            controller.selectServer(includeSettings: true).done { server in
                if let server {
                    controller.open(server: server)
                }
            }.catch { error in
                Current.Log.error("failed to select server: \(error)")
            }
        }
    }

    private func showSearchEntities() {
        webView.evaluateJavaScript(WebViewJavascriptCommands.searchEntitiesKeyEvent) { _, error in
            if let error {
                Current.Log.error("JavaScript error while trying to open entities search: \(error)")
            } else {
                Current.Log.info("Open entities search command sent to webview")
            }
        }
    }

    private func moveToServer(next: Bool) {
        let servers = Current.servers.all
        guard servers.count > 1, let currentIndex = servers.firstIndex(of: server) else { return }

        let nextIndex: Int
        if next {
            nextIndex = (currentIndex - 1 + servers.count) % servers.count
        } else {
            nextIndex = (currentIndex + 1) % servers.count
        }

        let nextServer = servers[nextIndex]

        Current.sceneManager.webViewWindowControllerPromise.done { controller in
            controller.open(server: nextServer).done { controller in
                let hud = MBProgressHUD.showAdded(to: controller.view, animated: true)
                hud.isUserInteractionEnabled = false
                hud.mode = .text
                hud.label.text = nextServer.info.name
                hud.hide(animated: true, afterDelay: 1.0)
            }
        }
    }
}
