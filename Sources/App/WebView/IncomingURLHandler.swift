import CallbackURLKit
import Foundation
import PromiseKit
import SafariServices
import Shared

class IncomingURLHandler {
    let windowController: WebViewWindowController
    init(windowController: WebViewWindowController) {
        self.windowController = windowController
        registerCallbackURLKitHandlers()
    }

    @discardableResult
    func handle(url: URL) -> Bool {
        Current.Log.verbose("Received URL: \(url)")
        var serviceData: [String: String] = [:]
        if let queryItems = url.queryItems {
            serviceData = queryItems
        }
        guard let host = url.host else { return true }
        switch host.lowercased() {
        case "x-callback-url":
            return Manager.shared.handleOpen(url: url)
        case "call_service":
            confirmAction(
                title: L10n.UrlHandler.CallService.Confirm.title,
                message: L10n.UrlHandler.CallService.Confirm.message(url.pathComponents[1]),
                handler: { self.callServiceURLHandler(url, serviceData) }
            )
        case "fire_event":
            confirmAction(
                title: L10n.UrlHandler.FireEvent.Confirm.title,
                message: L10n.UrlHandler.FireEvent.Confirm.message(url.pathComponents[1]),
                handler: { self.fireEventURLHandler(url, serviceData) }
            )
        case "send_location":
            confirmAction(
                title: L10n.UrlHandler.SendLocation.Confirm.title,
                message: L10n.UrlHandler.SendLocation.Confirm.message,
                handler: { self.sendLocationURLHandler() }
            )
        case "perform_action":
            performActionURLHandler(url, serviceData: serviceData)
        case "navigate": // homeassistant://navigate/lovelace/dashboard
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return false
            }

            components.scheme = nil
            components.host = nil

            let queryParameters = components.queryItems
            let isFromWidget = components.popWidgetAuthenticity()
            let server = components.popWidgetServer(isFromWidget: isFromWidget)

            guard let rawURL = components.url?.absoluteString else {
                return false
            }

            if let presenting = windowController.presentedViewController,
               presenting is SFSafariViewController {
                // Dismiss my.* controller if it's on top - we don't get any other indication
                presenting.dismiss(animated: true, completion: { [windowController] in
                    windowController.openSelectingServer(
                        from: .deeplink,
                        urlString: rawURL,
                        skipConfirm: true,
                        queryParameters: queryParameters
                    )
                })
            } else if let server = server {
                windowController.open(from: .deeplink, server: server, urlString: rawURL, skipConfirm: isFromWidget)
            } else {
                windowController.openSelectingServer(
                    from: .deeplink,
                    urlString: rawURL,
                    skipConfirm: isFromWidget,
                    queryParameters: queryParameters
                )
            }
        default:
            Current.Log.warning("Can't route incoming URL: \(url)")
            showAlert(title: L10n.errorLabel, message: L10n.UrlHandler.NoService.message(url.host!))
        }
        return true
    }

    @discardableResult
    func handle(userActivity: NSUserActivity) -> Bool {
        Current.Log.info(userActivity)

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
                if #available(iOS 13, *) {
                    if let intent = interaction.intent as? OpenPageIntent,
                       let panel = intent.page, let path = panel.identifier {
                        Current.Log.info("launching from shortcuts with panel \(panel)")

                        let urlString = "/" + path
                        if let server = Current.servers.server(for: panel) {
                            windowController.open(
                                from: .deeplink,
                                server: server,
                                urlString: urlString,
                                skipConfirm: true
                            )
                        } else {
                            windowController.openSelectingServer(
                                from: .deeplink,
                                urlString: urlString,
                                skipConfirm: true
                            )
                        }
                        return true
                    }
                }

                return false
            } else {
                return false
            }
        }
    }

    func handle(shortcutItem: UIApplicationShortcutItem) -> Promise<Void> {
        Current.backgroundTask(withName: "shortcut-item") { remaining -> Promise<Void> in
            if shortcutItem.type == "sendLocation" {
                return firstly {
                    Current.location.oneShotLocation(.AppShortcut, remaining)
                }.then { location in
                    when(fulfilled: Current.apis.map { api in
                        api.SubmitLocation(updateType: .AppShortcut, location: location, zone: nil)
                    })
                }.asVoid()
            } else {
                if let action = Current.realm().object(ofType: Action.self, forPrimaryKey: shortcutItem.type),
                   let server = Current.servers.server(for: action) {
                    Current.sceneManager.showFullScreenConfirm(
                        icon: MaterialDesignIcons(named: action.IconName),
                        text: action.Text,
                        onto: .value(windowController.window)
                    )

                    return Current.api(for: server).HandleAction(actionID: shortcutItem.type, source: .AppShortcut)
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

        windowController.webViewControllerPromise.done {
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
        windowController.webViewControllerPromise.done {
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
        windowController.present(SFSafariViewController(url: updatedURL), animated: false, completion: nil)

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
                                serviceData: serviceData
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
                return api.CallService(domain: domain, service: service, serviceData: serviceData)
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

        let source: HomeAssistantAPI.ActionSource = {
            if let sourceString = serviceData["source"],
               let source = HomeAssistantAPI.ActionSource(rawValue: sourceString) {
                return source
            } else {
                return .URLHandler
            }
        }()

        let actionID = url.pathComponents[1]

        guard let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID),
              let server = Current.servers.server(for: action) else {
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

        Current.api(for: server).HandleAction(actionID: actionID, source: source).cauterize()
    }
}
