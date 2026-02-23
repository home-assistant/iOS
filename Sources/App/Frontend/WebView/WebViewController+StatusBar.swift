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

    func setupStatusBarButtons(statusBarView: UIView) {
        let picker = UIButton(type: .system)
        picker.setTitle(server.info.name, for: .normal)
        picker.translatesAutoresizingMaskIntoConstraints = false

        let menuActions = Current.servers.all.map { server in
            UIAction(title: server.info.name, handler: { [weak self] _ in
                self?.openServer(server)
            })
        }

        // Using UIMenu since UIPickerView is not available on Catalyst
        picker.menu = UIMenu(title: L10n.WebView.ServerSelection.title, children: menuActions)
        picker.showsMenuAsPrimaryAction = true

        if let statusBarButtonsStack {
            statusBarButtonsStack.removeFromSuperview()
            self.statusBarButtonsStack = nil
        }

        let reloadButton = UIButton(type: .custom)
        reloadButton.setImage(UIImage(systemSymbol: .arrowClockwise), for: .normal)
        reloadButton.addTarget(self, action: #selector(refresh), for: .touchUpInside)

        // Wrap reload button in a circle view with padding
        let circleContainer = UIView()
        circleContainer.backgroundColor = UIColor.systemGray5
        circleContainer.layer.cornerRadius = 14 // Adjust size as needed
        circleContainer.translatesAutoresizingMaskIntoConstraints = false

        circleContainer.addSubview(reloadButton)
        reloadButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            circleContainer.widthAnchor.constraint(equalToConstant: 28),
            circleContainer.heightAnchor.constraint(equalToConstant: 28),
            reloadButton.centerXAnchor.constraint(equalTo: circleContainer.centerXAnchor),
            reloadButton.centerYAnchor.constraint(equalTo: circleContainer.centerYAnchor),
            reloadButton.widthAnchor.constraint(equalToConstant: 20),
            reloadButton.heightAnchor.constraint(equalToConstant: 20),
        ])

        let arrangedSubviews: [UIView] = Current.servers.all.count > 1 ? [circleContainer, picker] : [circleContainer]

        let stackView = UIStackView(arrangedSubviews: arrangedSubviews)
        stackView.axis = .horizontal
        stackView.spacing = DesignSystem.Spaces.one

        statusBarView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let openInSafariButton = WebViewControllerButtons.openInSafariButton
        openInSafariButton.addTarget(self, action: #selector(openServerInSafari), for: .touchUpInside)
        openInSafariButton.translatesAutoresizingMaskIntoConstraints = false

        let backButton = WebViewControllerButtons.backButton
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false

        let forwardButton = WebViewControllerButtons.forwardButton
        forwardButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        forwardButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = UIStackView(arrangedSubviews: [openInSafariButton, backButton, forwardButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = DesignSystem.Spaces.one
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.alignment = .center
        statusBarView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            stackView.rightAnchor.constraint(equalTo: statusBarView.rightAnchor, constant: -DesignSystem.Spaces.half),
            stackView.topAnchor.constraint(equalTo: statusBarView.topAnchor, constant: DesignSystem.Spaces.half),
            buttonStack.topAnchor.constraint(equalTo: statusBarView.topAnchor),
            openInSafariButton.widthAnchor.constraint(equalToConstant: 11),
            openInSafariButton.heightAnchor.constraint(equalToConstant: 11),
        ])

        // Magic numbers to position it nicely in macOS bar
        if #available(macOS 26.0, *) {
            NSLayoutConstraint.activate([
                buttonStack.leftAnchor.constraint(equalTo: statusBarView.leftAnchor, constant: 78),
                buttonStack.heightAnchor.constraint(equalToConstant: 30),
            ])
        } else {
            NSLayoutConstraint.activate([
                buttonStack.leftAnchor.constraint(equalTo: statusBarView.leftAnchor, constant: 68),
                buttonStack.heightAnchor.constraint(equalToConstant: 27),
            ])
        }

        statusBarButtonsStack = stackView
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
