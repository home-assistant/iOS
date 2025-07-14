import Foundation
import MBProgressHUD
import Shared

// MARK: - Gestures

final class WebViewGestureHandler {
    weak var webView: WebViewControllerProtocol?

    func handleGestureAction(_ action: HAGestureAction) {
        switch action {
        case .assist:
            showAssistThroughKeyEvent()
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
            webView?.showSettingsViewController()
        case .openDebug:
            webView?.openDebug()
        case .searchEntities:
            showSearchEntities()
        case .searchDevices:
            showSearchDevices()
        case .searchCommands:
            showSearchCommands()
        case .none:
            /* no-op */
            break
        }
    }

    private func showSidebar() {
        webView?.webViewExternalMessageHandler
            .sendExternalBus(message: .init(command: WebViewExternalBusOutgoingMessage.showSidebar.rawValue))
    }

    private func webViewNavigateBack() {
        if webView?.canGoBack ?? false {
            webView?.goBack()
        }
    }

    private func webViewNavigateForward() {
        if webView?.canGoForward ?? false {
            webView?.goForward()
        }
    }

    private func showServersList() {
        Current.sceneManager.webViewWindowControllerPromise.done { controller in
            controller.selectServer(includeSettings: true) { server in
                controller.open(server: server)
            }
        }
    }

    private func showSearchEntities() {
        webView?.evaluateJavaScript(WebViewJavascriptCommands.searchEntitiesKeyEvent) { _, error in
            if let error {
                Current.Log.error("JavaScript error while trying to open entities search: \(error)")
            } else {
                Current.Log.info("Open entities search command sent to webview")
            }
        }
    }

    private func showSearchDevices() {
        webView?.evaluateJavaScript(WebViewJavascriptCommands.searchDevicesKeyEvent) { _, error in
            if let error {
                Current.Log.error("JavaScript error while trying to open devices search: \(error)")
            } else {
                Current.Log.info("Open devices search command sent to webview")
            }
        }
    }

    private func showSearchCommands() {
        webView?.evaluateJavaScript(WebViewJavascriptCommands.searchCommandsKeyEvent) { _, error in
            if let error {
                Current.Log.error("JavaScript error while trying to open commands search: \(error)")
            } else {
                Current.Log.info("Open commands search command sent to webview")
            }
        }
    }

    private func showAssistThroughKeyEvent() {
        webView?.evaluateJavaScript(WebViewJavascriptCommands.assistKeyEvent) { _, error in
            if let error {
                Current.Log.error("JavaScript error while trying to open assist: \(error)")
            } else {
                Current.Log.info("Open assist command sent to webview")
            }
        }
    }

    private func moveToServer(next: Bool) {
        guard let server = webView?.server else {
            Current.Log.error("No server available to switch")
            return
        }
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
