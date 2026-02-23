import PromiseKit
import Shared
import SwiftUI
import UIKit
@preconcurrency import WebKit

// MARK: - Public Navigation API

public extension WebViewController {
    /// avoidUnecessaryReload Avoids reloading when the URL is the same as the current one
    func open(inline url: URL, avoidUnecessaryReload: Bool = false) {
        loadViewIfNeeded()

        // these paths do not show frontend pages, and so we don't want to display them in our webview
        // otherwise the user will get stuck. e.g. /api is loaded by frigate to show video clips and images
        let ignoredPaths = [
            "/api",
            "/static",
            "/hacsfiles",
            "/local",
        ]

        if ignoredPaths.allSatisfy({ !url.path.hasPrefix($0) }) {
            if avoidUnecessaryReload, webView.url?.isEqualIgnoringQueryParams(to: url) == true {
                Current.Log
                    .info(
                        "Not reloading WebView when open(inline) was requested, URL is the same as current and avoidUnecessaryReload is true"
                    )
                return
            }
            load(request: URLRequest(url: url))
        } else {
            openURLInBrowser(url, self)
        }
    }

    /// Used for OpenPage intent
    func openPanel(_ url: URL) {
        loadViewIfNeeded()

        guard url.queryItems?[AppConstants.QueryItems.openMoreInfoDialog.rawValue] == nil || server.info
            .version >= .canNavigateMoreInfoDialogThroughFrontend else {
            load(request: URLRequest(url: url))
            Current.Log.verbose("Opening more-info dialog for URL: \(url)")
            return
        }

        let urlPathIncludingQueryParams = {
            // If the URL has query parameters, we need to include them in the path to ensure proper navigation
            if let query = url.query, !query.isEmpty {
                return "\(url.path)?\(query)"
            }
            return url.path
        }()

        navigate(path: urlPathIncludingQueryParams) { [weak self] success in
            if !success {
                Current.Log.warning("Failed to navigate through frontend for URL: \(url)")
                // Fallback to loading the URL directly if navigation fails
                self?.load(request: URLRequest(url: url))
            }
        }
    }

    /// Uses external bus to navigate through frontend instead of loading the page from scratch using the web view
    /// Returns true if the navigation was successful
    private func navigate(path: String, completion: @escaping (Bool) -> Void) {
        guard server.info.version >= .canNavigateThroughFrontend else {
            Current.Log.warning("Cannot navigate through frontend, core version is too low")
            completion(false)
            return
        }
        Current.Log.verbose("Requesting navigation using external bus to path: \(path)")
        webViewExternalMessageHandler.sendExternalBus(message: .init(
            command: WebViewExternalBusOutgoingMessage.navigate.rawValue,
            payload: [
                "path": path,
            ]
        )).pipe { result in
            switch result {
            case .fulfilled:
                completion(true)
            case .rejected:
                completion(false)
            }
        }
    }

    /// Manual reload does not take care of internal/external URL changes, prefer using `refresh()`
    internal func reload() {
        Current.Log.verbose("Reload webView requested")
        webView.reload()
    }

    func showSettingsViewController() {
        getLatestConfig()
        if Current.sceneManager.supportsMultipleScenes, Current.isCatalyst {
            Current.sceneManager.activateAnyScene(for: .settings)
        } else {
            // Use SwiftUI SettingsView wrapped in hosting controller
            let settingsView = SettingsView().embeddedInHostingController()
            settingsView.view.tag = WebViewControllerOverlayedViewTags.settingsView.rawValue
            presentOverlayController(controller: settingsView, animated: true)
        }
    }

    func openActionAutomationEditor(actionId: String) {
        guard server.info.version >= .externalBusCommandAutomationEditor else {
            showActionAutomationEditorNotAvailable()
            return
        }
        _ = webViewExternalMessageHandler.sendExternalBus(message: .init(
            command: WebViewExternalBusOutgoingMessage.showAutomationEditor.rawValue,
            payload: [
                "config": [
                    "trigger": [
                        [
                            "platform": "event",
                            "event_type": "ios.action_fired",
                            "event_data": [
                                "actionID": actionId,
                            ],
                        ],
                    ],
                ],
            ]
        ))
    }

    internal func getLatestConfig() {
        _ = Current.api(for: server)?.getConfig()
    }
}
