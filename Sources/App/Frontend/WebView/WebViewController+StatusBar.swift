import Shared
import SwiftUI
import UIKit
@preconcurrency import WebKit

// MARK: - Status Bar & Toolbar

extension WebViewController {
    func setupStatusBarView() -> UIView {
        let statusBarView = UIView()
        statusBarView.tag = 111
        self.statusBarView = statusBarView

        view.addSubview(statusBarView)
        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            statusBarView.topAnchor.constraint(equalTo: view.topAnchor),
            statusBarView.leftAnchor.constraint(equalTo: view.leftAnchor),
            statusBarView.rightAnchor.constraint(equalTo: view.rightAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])

        if Current.isCatalyst {
            setupStatusBarButtons(in: statusBarView)
        }
        return statusBarView
    }

    func setupStatusBarButtons(in statusBarView: UIView) {
        // Remove existing stack if present
        if let statusBarButtonsStack {
            statusBarButtonsStack.removeFromSuperview()
            self.statusBarButtonsStack = nil
        }

        let configuration = StatusBarButtonsConfigurator.Configuration(
            server: server,
            servers: Current.servers.all,
            actions: .init(
                refresh: { [weak self] in
                    self?.refresh()
                },
                openServer: { [weak self] server in
                    self?.openServer(server)
                },
                openInSafari: { [weak self] in
                    self?.openServerInSafari()
                },
                goBack: { [weak self] in
                    self?.goBack()
                },
                goForward: { [weak self] in
                    self?.goForward()
                },
                copy: { [weak self] in
                    self?.copyCurrentSelectedContent()
                },
                paste: { [weak self] in
                    self?.pasteContent()
                }
            )
        )

        statusBarButtonsStack = StatusBarButtonsConfigurator.setupButtons(
            in: statusBarView,
            configuration: configuration
        )
    }

    func openServer(_ server: Server) {
        Current.sceneManager.webViewWindowControllerPromise.done { controller in
            controller.open(server: server)
        }
    }

    @objc func openServerInSafari() {
        if let url = webView.url {
            guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return
            }
            // Remove external_auth=1 query item from URL
            urlComponents.queryItems = urlComponents.queryItems?.filter { $0.name != "external_auth" }

            if let url = urlComponents.url {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

    @objc func copyCurrentSelectedContent() {
        // Get selected text from the web view
        webView.evaluateJavaScript("window.getSelection().toString();") { result, error in
            Current.Log
                .error(
                    "Copy selected content result: \(String(describing: result)), error: \(String(describing: error))"
                )
            if let selectedText = result as? String, !selectedText.isEmpty {
                // Copy to clipboard
                UIPasteboard.general.string = selectedText
            }
        }
    }

    @objc func pasteContent() {
        // Programmatically trigger the standard iOS paste action by calling the paste: selector
        // This mimics the user selecting "Paste" from the context menu and allows paste to work properly
        if webView.responds(to: #selector(paste(_:))) {
            webView.perform(#selector(paste(_:)), with: nil)
        }
    }

    @available(iOS 16.0, *)
    @objc func showFindInteraction() {
        // Present the find interaction UI
        if let findInteraction = webView.findInteraction {
            findInteraction.presentFindNavigator(showingReplace: false)
        }
    }
}
