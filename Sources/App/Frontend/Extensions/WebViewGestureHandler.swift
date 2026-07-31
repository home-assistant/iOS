import Foundation
import Shared

// MARK: - Gestures

final class WebViewGestureHandler {
    weak var webView: WebViewControllerProtocol?

    func handleGestureAction(_ action: HAGestureAction) {
        if action != .none {
            Current.impactFeedback.impactOccurred(style: .light)
        }
        switch action {
        case .assist:
            showAssistThroughKeyEvent()
        case .showSidebar:
            showSidebar()
        case .backPage:
            webViewNavigateBack()
        case .nextPage:
            webViewNavigateForward()
        case .smartBack:
            smartBack()
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
        case .quickSearch:
            showQuickSearch()
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
            .cauterize()
    }

    @discardableResult
    private func webViewNavigateBack() -> Bool {
        guard webView?.canGoBack ?? false else { return false }
        webView?.goBack()
        return true
    }

    private func webViewNavigateForward() {
        if webView?.canGoForward ?? false {
            webView?.goForward()
        }
    }

    private func smartBack() {
        if !webViewNavigateBack() {
            showSidebar()
        }
    }

    private func showServersList() {
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.selectServer(prompt: nil, includeSettings: true) { server in
                coordinator.activate(server: server)
            }
        }
    }

    private func showQuickSearch() {
        // Use Ctrl+K for HA 2026.2+, fallback to E key for older versions
        let command: String
        if let serverVersion = webView?.server.info.version,
           serverVersion >= .quickSearchKeyboardShortcut {
            command = WebViewJavascriptCommands.quickSearchKeyEvent
        } else {
            command = WebViewJavascriptCommands.searchEntitiesKeyEvent
        }
        webView?.evaluateJavaScript(command) { _, error in
            if let error {
                Current.Log.error("JavaScript error while trying to open quick search: \(error)")
            } else {
                Current.Log.info("Open quick search command sent to webview")
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

        // Not `activate(server:)`: cycling servers with a gesture bypasses the server picker, so it
        // switches in place without sending the user back to the Home Assistant root.
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.open(server: nextServer)
        }
    }
}
