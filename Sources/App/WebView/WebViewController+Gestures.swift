import Foundation
import MBProgressHUD
import Shared

// MARK: - Gestures

extension WebViewController {
    func handleGestureAction(_ action: HAGestureAction) {
        switch action {
        case .showSidebar:
            webViewExternalMessageHandler.sendExternalBus(message: .init(command: "sidebar/show"))
        case .backPage:
            if webView.canGoBack {
                webView.goBack()
            }
        case .nextPage:
            if webView.canGoForward {
                webView.goForward()
            }
        case .showServersList:
            Current.sceneManager.webViewWindowControllerPromise.done { controller in
                controller.selectServer(includeSettings: true).done { server in
                    if let server {
                        controller.open(server: server)
                    }
                }.catch { error in
                    Current.Log.error("failed to select server: \(error)")
                }
            }
        case .nextServer:
            moveToServer(next: true)
            displayChangeServerHUD(next: true)
        case .previousServer:
            moveToServer(next: false)
            displayChangeServerHUD(next: false)
        case .showSettings:
            showSettingsViewController()
        case .none:
            /* no-op */
            break
        case .openDebug:
            openDebug()
        case .searchEntities:
            showSearchEntities()
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

    private func displayChangeServerHUD(next: Bool) {
        let icon: MaterialDesignIcons = next ? .arrowRightIcon : .arrowLeftIcon
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.isUserInteractionEnabled = false
        hud.customView = with(IconImageView(frame: CGRect(x: 0, y: 0, width: 37, height: 37))) {
            $0.iconDrawable = icon
        }
        hud.mode = .customView
        hud.hide(animated: true, afterDelay: 1.0)
    }
}
