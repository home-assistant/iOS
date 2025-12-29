import CallbackURLKit
import Foundation
import PromiseKit
import SafariServices
import Shared
import SwiftUI

class IncomingURLHandler {
    private(set) weak var windowController: WebViewWindowController!

    init(windowController: WebViewWindowController) {
        self.windowController = windowController
        registerCallbackURLKitHandlers()
    }

    enum IncomingURLAction: String {
        case xCallbackURL = "x-callback-url"
        case callService = "call_service"
        case fireEvent = "fire_event"
        case sendLocation = "send_location"
        case performAction = "perform_action"
        case assist
        case navigate
        case invite
        case createCustomWidget = "createcustomwidget"
        case camera
        case experimentalDashboard = "experimental-dashboard"
    }

    // swiftlint:disable cyclomatic_complexity
    @discardableResult
    func handle(url: URL) -> Bool {
        Current.Log.verbose("Received URL: \(url)")
        var serviceData: [String: String] = [:]
        if let queryItems = url.queryItems {
            serviceData = queryItems
        }
        guard let host = url.host else { return true }
        if let requestedAction = IncomingURLAction(rawValue: host.lowercased()) {
            switch requestedAction {
            case .xCallbackURL:
                return Manager.shared.handleOpen(url: url)
            case .callService:
                confirmAction(
                    title: L10n.UrlHandler.CallService.Confirm.title,
                    message: L10n.UrlHandler.CallService.Confirm.message(url.pathComponents[1]),
                    handler: { self.callServiceURLHandler(url, serviceData) }
                )
            case .fireEvent:
                confirmAction(
                    title: L10n.UrlHandler.FireEvent.Confirm.title,
                    message: L10n.UrlHandler.FireEvent.Confirm.message(url.pathComponents[1]),
                    handler: { self.fireEventURLHandler(url, serviceData) }
                )
            case .sendLocation:
                confirmAction(
                    title: L10n.UrlHandler.SendLocation.Confirm.title,
                    message: L10n.UrlHandler.SendLocation.Confirm.message,
                    handler: { self.sendLocationURLHandler() }
                )
            case .performAction:
                performActionURLHandler(url, serviceData: serviceData)
            case .camera:
                guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    return false
                }
                components.scheme = nil
                components.host = nil

                let queryParameters = components.queryItems
                let serverId = queryParameters?.first(where: { $0.name == "serverId" })?.value
                let entityId = queryParameters?.first(where: { $0.name == "entityId" })?.value

                // If no entityId is provided, show the camera list
                if entityId == nil {
                    Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                        .done { webViewController in
                            let view = CameraListView(serverId: serverId).embeddedInHostingController()
                            view.modalPresentationStyle = .pageSheet
                            if #available(iOS 16.0, *) {
                                view.sheetPresentationController?.detents = [.medium(), .large()]
                            }
                            webViewController.present(view, animated: true)
                        }
                    return true
                }

                guard let entityId,
                      let server = Current.servers.all.first(where: { server in
                          server.identifier.rawValue == serverId
                      }) else {
                    Current.Log.error("No server found for open camera URL: \(url)")
                    return false
                }
                Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                    .done { webViewController in
                        let view = WebRTCVideoPlayerView(
                            server: server,
                            cameraEntityId: entityId
                        ).embeddedInHostingController()
                        view.modalPresentationStyle = .overFullScreen
                        webViewController.present(view, animated: true)
                    }
            case .navigate: // homeassistant://navigate/lovelace/dashboard
                guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    return false
                }

                components.scheme = nil
                components.host = nil

                let queryParameters = components.queryItems
                let isFromWidget = components.popWidgetAuthenticity()
                let server = components.popWidgetServer(isFromWidget: isFromWidget)
                let isComingFromAppIntent: Bool = {
                    if let value = queryParameters?
                        .first(where: { $0.name == AppConstants.QueryItems.isComingFromAppIntent.rawValue })?.value {
                        return Bool(value) ?? false
                    } else {
                        return false
                    }
                }()

                guard let rawURL = components.url?.absoluteString else {
                    return false
                }

                if
                    let presenting = windowController.presentedViewController,
                    presenting is SFSafariViewController {
                    // Dismiss my.* controller if it's on top - we don't get any other indication
                    presenting.dismiss(animated: true, completion: { [windowController] in
                        windowController?.openSelectingServer(
                            from: .deeplink,
                            urlString: rawURL,
                            skipConfirm: true,
                            queryParameters: queryParameters,
                            isComingFromAppIntent: false
                        )
                    })
                } else if let server {
                    windowController.open(
                        from: .deeplink,
                        server: server,
                        urlString: rawURL,
                        skipConfirm: isFromWidget,
                        isComingFromAppIntent: isComingFromAppIntent
                    )
                } else {
                    windowController.openSelectingServer(
                        from: .deeplink,
                        urlString: rawURL,
                        skipConfirm: isFromWidget,
                        queryParameters: queryParameters,
                        isComingFromAppIntent: isComingFromAppIntent
                    )
                }
            case .assist:
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let queryParameters = components.queryItems else {
                    return false
                }

                let serverId = queryParameters.first(where: { $0.name == "serverId" })?.value ?? ""
                let pipelineId = queryParameters.first(where: { $0.name == "pipelineId" })?.value ?? ""
                let startlistening = Bool(
                    queryParameters.first(where: { $0.name == "startListening" })?
                        .value ?? "false"
                ) ?? true

                guard let server = Current.servers.all.first(where: {
                    $0.identifier.rawValue == serverId
                }) ?? Current.servers.all.first else { return false }

                Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                    .done { webViewController in
                        webViewController.webViewExternalMessageHandler.showAssist(
                            server: server,
                            pipeline: pipelineId,
                            autoStartRecording: startlistening
                        )
                    }
            case .createCustomWidget:
                Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                    .done { webViewController in
                        let controller = UIHostingController(rootView: AnyView(
                            NavigationView {
                                WidgetBuilderView()
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            CloseButton {
                                                webViewController.dismissOverlayController(
                                                    animated: true,
                                                    completion: nil
                                                )
                                            }
                                        }
                                    }
                            }
                        ))
                        webViewController.presentOverlayController(controller: controller, animated: true)
                    }
            case .invite:
                // homeassistant://invite#url=http%3A%2F%2Fhomeassistant.local%3A8123
                Current.Log.verbose("Received Home Assistant invitation URL: \(url)")
                guard let fragment = url.fragment else {
                    Current.Log.error("Home Assistant invitation does not contain a fragment (e.g. #url=...)")
                    return false
                }

                // Convert fragment into query items (#url=... -> ?url=...)
                let components = URLComponents(string: "?\(fragment)")
                let urlParam = components?.queryItems?.first(where: { $0.name == "url" })?.value

                let inviteUrl = URL(string: urlParam.orEmpty)

                Current.sceneManager.webViewWindowControllerPromise.done { windowController in
                    windowController.presentInvitation(url: inviteUrl)
                }
            case .experimentalDashboard:
                // homeassistant://experimental-dashboard/{serverId}
                let serverId = url.queryItems?["serverId"] ?? ""

                guard let server = Current.servers.all.first(where: { server in
                    server.identifier.rawValue == serverId
                }) else {
                    Current.Log.error("No server found for experimental dashboard with ID: \(serverId)")
                    return false
                }

                Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                    .done { controller in
                        if #available(iOS 26.0, *) {
                            let view = HomeView(server: server).embeddedInHostingController()
                            view.modalPresentationStyle = .fullScreen
                            controller.presentOverlayController(controller: view, animated: false)
                        }
                    }
            }
        } else {
            Current.Log.warning("Can't route incoming URL: \(url)")
            showAlert(title: L10n.errorLabel, message: L10n.UrlHandler.NoService.message(url.host!))
        }
        return true
    }

    @discardableResult
    func handle(userActivity: NSUserActivity) -> Bool {
        Current.Log.info(userActivity)

        if let assistInAppIntent = userActivity.interaction?.intent as? AssistInAppIntent {
            guard let server = Current.servers.server(for: assistInAppIntent) ?? Current.servers.all.first else { return false }
            let pipeline = assistInAppIntent.pipeline
            let autoStartRecording = Bool(exactly: assistInAppIntent.withVoice ?? 0) ?? false

            windowController.webViewControllerPromise.pipe { result in
                switch result {
                case let .fulfilled(webView):
                    webView.webViewExternalMessageHandler.showAssist(
                        server: server,
                        pipeline: pipeline?.identifier ?? "",
                        autoStartRecording: autoStartRecording
                    )
                case let .rejected(error):
                    Current.Log.error("Failed to obtain webview to open Assist In App: \(error.localizedDescription)")
                }
            }

            return true
        }

        switch Current.tags.handle(userActivity: userActivity) {
        case let .handled(type):
            let (icon, text) = { () -> (MaterialDesignIcons, String) in
                switch type {
                case .nfc:
                    return (.nfcVariantIcon, L10n.Nfc.tagRead)
                case .generic:
                    return (.qrcodeIcon, L10n.Nfc.genericTagRead)
                }
            }()

            Current.sceneManager.showFullScreenConfirm(
                icon: icon,
                text: text,
                onto: .value(windowController.window)
            )
            return true
        case let .open(url):
            // NFC-based URL
            return handle(url: url)
        case .unhandled:
            // not a tag
            if let url = userActivity.webpageURL, url.host?.lowercased() == "my.home-assistant.io" {
                return showMy(for: url)
            } else if let interaction = userActivity.interaction {
                if
                    let intent = interaction.intent as? OpenPageIntent,
                    let panel = intent.page, let path = panel.identifier {
                    Current.Log.info("launching from shortcuts with panel \(panel)")

                    let urlString = "/" + path
                    if let server = Current.servers.server(for: panel) {
                        windowController.open(
                            from: .deeplink,
                            server: server,
                            urlString: urlString,
                            skipConfirm: true,
                            isComingFromAppIntent: false
                        )
                    } else {
                        windowController.openSelectingServer(
                            from: .deeplink,
                            urlString: urlString,
                            skipConfirm: true,
                            isComingFromAppIntent: false
                        )
                    }
                    return true
                }

                return false
            } else {
                return false
            }
        }
    }

    func handle(shortcutItem: UIApplicationShortcutItem) -> Promise<Void> {
        Current.backgroundTask(withName: BackgroundTask.shortcutItem.rawValue) { remaining -> Promise<Void> in
            switch shortcutItem.type {
            case HAApplicationShortcutItem.sendLocation.rawValue:
                return firstly {
                    Current.location.oneShotLocation(.AppShortcut, remaining)
                }.then { location in
                    when(fulfilled: Current.apis.map { api in
                        api.SubmitLocation(updateType: .AppShortcut, location: location, zone: nil)
                    })
                }.asVoid()
            case HAApplicationShortcutItem.openSettings.rawValue:
                if Current.isCatalyst, Current.settingsStore.macNativeFeaturesOnly {
                    // Close window to avoid empty window left behind
                    for window in UIApplication.shared.windows {
                        if let scene = window.windowScene {
                            UIApplication.shared.requestSceneSessionDestruction(
                                scene.session,
                                options: nil,
                                errorHandler: nil
                            )
                        }
                    }
                }
                Current.sceneManager.activateAnyScene(for: .settings)
                return .value(())
            default:
                if
                    let action = Current.realm().object(ofType: Action.self, forPrimaryKey: shortcutItem.type),
                    let server = Current.servers.server(for: action) {
                    Current.sceneManager.showFullScreenConfirm(
                        icon: MaterialDesignIcons(named: action.IconName),
                        text: action.Text,
                        onto: .value(windowController.window)
                    )

                    return Current.api(for: server)?
                        .HandleAction(actionID: shortcutItem.type, source: .AppShortcut) ??
                        .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
                } else {
                    return .init(error: HomeAssistantAPI.APIError.notConfigured)
                }
            }
        }
    }

    private func confirmAction(
        title: String,
        message: String,
        handler: @escaping () -> Void,
        cancelHandler: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertController.Style.alert
        )

        alert.addAction(UIAlertAction(
            title: L10n.cancelLabel,
            style: .cancel,
            handler: { _ in
                cancelHandler?()
            }
        ))

        alert.addAction(UIAlertAction(
            title: L10n.yesLabel,
            style: .default,
            handler: { _ in
                handler()
            }
        ))

        windowController?.webViewControllerPromise.done {
            $0.present(alert, animated: true, completion: nil)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
        windowController?.webViewControllerPromise.done {
            $0.present(alert, animated: true, completion: nil)
        }
    }

    private func showMy(for url: URL) -> Bool {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Current.Log.info("couldn't create url components out of \(url)")
            return false
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(.init(name: "mobile", value: "1"))
        components.queryItems = queryItems

        guard let updatedURL = components.url else {
            return false
        }

        // not animated in because it looks weird during the app launch animation
        windowController?.present(SFSafariViewController(url: updatedURL), animated: false, completion: nil)

        return true
    }
}

extension IncomingURLHandler {
    enum XCallbackError: FailureCallbackError {
        case generalError
        case eventNameMissing
        case serviceMissing
        case templateMissing

        var code: Int {
            switch self {
            case .generalError:
                return 0
            case .eventNameMissing:
                return 1
            case .serviceMissing:
                return 2
            case .templateMissing:
                return 2
            }
        }

        var message: String {
            switch self {
            case .generalError:
                return L10n.UrlHandler.XCallbackUrl.Error.general
            case .eventNameMissing:
                return L10n.UrlHandler.XCallbackUrl.Error.eventNameMissing
            case .serviceMissing:
                return L10n.UrlHandler.XCallbackUrl.Error.serviceMissing
            case .templateMissing:
                return L10n.UrlHandler.XCallbackUrl.Error.templateMissing
            }
        }
    }

    private func registerCallbackURLKitHandlers() {
        Manager.shared.callbackURLScheme = Manager.urlSchemes?.first

        Manager.shared["fire_event"] = { parameters, success, failure, cancel in
            guard let eventName = parameters["eventName"] else {
                failure(XCallbackError.eventNameMissing)
                return
            }

            var cleanParamters = parameters
            cleanParamters.removeValue(forKey: "eventName")
            let eventData = cleanParamters

            self.confirmAction(
                title: L10n.UrlHandler.FireEvent.Confirm.title,
                message: L10n.UrlHandler.FireEvent.Confirm.message(eventName),
                handler: {
                    firstly { () -> Promise<Void> in
                        if let api = Current.apis.first {
                            return api.CreateEvent(eventType: eventName, eventData: eventData)
                        } else {
                            throw XCallbackError.generalError
                        }
                    }.done {
                        success(nil)
                    }.catch { error in
                        Current.Log.error("Received error from createEvent during X-Callback-URL call: \(error)")
                        failure(XCallbackError.generalError)
                    }
                },
                cancelHandler: {
                    cancel()
                }
            )
        }

        Manager.shared["call_service"] = { parameters, success, failure, cancel in
            guard let service = parameters["service"] else {
                failure(XCallbackError.serviceMissing)
                return
            }

            let splitService = service.components(separatedBy: ".")
            let serviceDomain = splitService[0]
            let serviceName = splitService[1]

            var cleanParamters = parameters
            cleanParamters.removeValue(forKey: "service")
            let serviceData = cleanParamters

            self.confirmAction(
                title: L10n.UrlHandler.CallService.Confirm.title,
                message: L10n.UrlHandler.CallService.Confirm.message(service),
                handler: {
                    firstly { () -> Promise<Void> in
                        if let api = Current.apis.first {
                            return api.CallService(
                                domain: serviceDomain,
                                service: serviceName,
                                serviceData: serviceData,
                                triggerSource: .URLHandler
                            )
                        } else {
                            throw XCallbackError.generalError
                        }
                    }.done {
                        success(nil)
                    }.catch { error in
                        Current.Log.error("Received error from callService during X-Callback-URL call: \(error)")
                        failure(XCallbackError.generalError)
                    }
                },
                cancelHandler: {
                    cancel()
                }
            )
        }

        Manager.shared["send_location"] = { _, success, failure, cancel in

            self.confirmAction(
                title: L10n.UrlHandler.SendLocation.Confirm.title,
                message: L10n.UrlHandler.SendLocation.Confirm.message,
                handler: {
                    firstly {
                        Current.location.oneShotLocation(.XCallbackURL, nil)
                    }.then { location in
                        when(fulfilled: Current.apis.map { api in
                            api.SubmitLocation(updateType: .XCallbackURL, location: location, zone: nil)
                        })
                    }.done { _ in
                        success(nil)
                    }.catch { error in
                        Current.Log.error("Received error from getAndSendLocation during X-Callback-URL call: \(error)")
                        failure(XCallbackError.generalError)
                    }
                },
                cancelHandler: {
                    cancel()
                }
            )
        }

        Manager.shared["render_template"] = { parameters, success, failure, cancel in
            guard let template = parameters["template"] else {
                failure(XCallbackError.templateMissing)
                return
            }

            var cleanParamters = parameters
            cleanParamters.removeValue(forKey: "template")
            let variablesDict = cleanParamters

            self.confirmAction(
                title: L10n.UrlHandler.RenderTemplate.Confirm.title,
                message: L10n.UrlHandler.RenderTemplate.Confirm.message(template),
                handler: {
                    if let api = Current.apis.first {
                        api.connection.subscribe(
                            to: .renderTemplate(template, variables: variablesDict),
                            initiated: { result in
                                if case let .failure(error) = result {
                                    Current.Log
                                        .error(
                                            "Received error from RenderTemplate during X-Callback-URL call: \(error)"
                                        )
                                    failure(XCallbackError.generalError)
                                }
                            }, handler: { token, data in
                                token.cancel()
                                success(["rendered": String(describing: data.result)])
                            }
                        )
                    } else {
                        failure(XCallbackError.generalError)
                    }
                },
                cancelHandler: {
                    cancel()
                }
            )
        }
    }

    private func fireEventURLHandler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity

        firstly { () -> Promise<Void> in
            if let api = Current.apis.first {
                return api.CreateEvent(eventType: url.pathComponents[1], eventData: serviceData)
            } else {
                throw HomeAssistantAPI.APIError.notConfigured
            }
        }.done {
            self.showAlert(
                title: L10n.UrlHandler.FireEvent.Success.title,
                message: L10n.UrlHandler.FireEvent.Success.message(url.pathComponents[1])
            )
        }.catch { error in
            self.showAlert(
                title: L10n.errorLabel,
                message: L10n.UrlHandler.FireEvent.Error.message(
                    url.pathComponents[1],
                    error.localizedDescription
                )
            )
        }
    }

    private func callServiceURLHandler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
        let domain = url.pathComponents[1].components(separatedBy: ".")[0]
        let service = url.pathComponents[1].components(separatedBy: ".")[1]

        firstly { () -> Promise<Void> in
            if let api = Current.apis.first {
                return api.CallService(
                    domain: domain,
                    service: service,
                    serviceData: serviceData,
                    triggerSource: .URLHandler
                )
            } else {
                throw HomeAssistantAPI.APIError.notConfigured
            }
        }.done { _ in
            self.showAlert(
                title: L10n.UrlHandler.CallService.Success.title,
                message: L10n.UrlHandler.CallService.Success.message(url.pathComponents[1])
            )
        }.catch { error in
            self.showAlert(
                title: L10n.errorLabel,
                message: L10n.UrlHandler.CallService.Error.message(
                    url.pathComponents[1],
                    error.localizedDescription
                )
            )
        }
    }

    private func sendLocationURLHandler() {
        // homeassistant://send_location/
        firstly {
            Current.location.oneShotLocation(.URLScheme, nil)
        }.then { location in
            when(fulfilled: Current.apis.map { api in
                api.SubmitLocation(updateType: .URLScheme, location: location, zone: nil)
            })
        }.done { _ in
            self.showAlert(
                title: L10n.UrlHandler.SendLocation.Success.title,
                message: L10n.UrlHandler.SendLocation.Success.message
            )
        }.catch { error in
            self.showAlert(
                title: L10n.errorLabel,
                message: L10n.UrlHandler.SendLocation.Error.message(error.localizedDescription)
            )
        }
    }

    private func performActionURLHandler(_ url: URL, serviceData: [String: String]) {
        let pathComponents = url.pathComponents
        guard pathComponents.count > 1 else {
            Current.Log.error("not enough path components for perform action handler")
            return
        }

        let source: AppTriggerSource = {
            if
                let sourceString = serviceData["source"],
                let source = AppTriggerSource(rawValue: sourceString) {
                return source
            } else {
                return .URLHandler
            }
        }()

        let actionID = url.pathComponents[1]

        guard
            let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID),
            let server = Current.servers.server(for: action),
            let api = Current.api(for: server) else {
            Current.sceneManager.showFullScreenConfirm(
                icon: .alertCircleIcon,
                text: L10n.UrlHandler.Error.actionNotFound,
                onto: .value(windowController.window)
            )
            return
        }

        Current.sceneManager.showFullScreenConfirm(
            icon: MaterialDesignIcons(named: action.IconName),
            text: action.Text,
            onto: .value(windowController.window)
        )

        api.HandleAction(actionID: actionID, source: source).cauterize()
    }
}
