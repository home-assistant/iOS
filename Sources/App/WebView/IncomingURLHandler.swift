import Foundation
import Shared
import CallbackURLKit
import PromiseKit

class IncomingURLHandler {
    let windowController: WebViewWindowController
    init(windowController: WebViewWindowController) {
        self.windowController = windowController
        self.registerCallbackURLKitHandlers()
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
            callServiceURLHandler(url, serviceData)
        case "fire_event":
            fireEventURLHandler(url, serviceData)
        case "send_location":
            sendLocationURLHandler()
        case "perform_action":
            performActionURLHandler(url, serviceData: serviceData)
        case "auth-callback": // homeassistant://auth-callback
           NotificationCenter.default.post(name: Notification.Name("AuthCallback"), object: nil,
                                           userInfo: ["url": url])
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
        case .handled(let type):
            let (icon, text) = { () -> (MaterialDesignIcons, String) in
                switch type {
                case .nfc:
                    return (.nfcVariantIcon, L10n.Nfc.tagRead)
                case .generic:
                    return (.qrcodeIcon, L10n.Nfc.genericTagRead)
                }
            }()

            Current.sceneManager.showFullScreenConfirm(icon: icon, text: text)
            return true
        case .unhandled:
            return false
        case .open(let url):
            // NFC-based URL
            return handle(url: url)
        }
    }

    func handle(shortcutItem: UIApplicationShortcutItem) -> Promise<Void> {
        return Current.backgroundTask(withName: "shortcut-item") { remaining -> Promise<Void> in
            Current.api.then { api -> Promise<Void> in
                if shortcutItem.type == "sendLocation" {
                    return api.GetAndSendLocation(trigger: .AppShortcut, maximumBackgroundTime: remaining)
                } else {
                    return api.HandleAction(actionID: shortcutItem.type, source: .AppShortcut)
                }
            }
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

    // swiftlint:disable:next function_body_length
    private func registerCallbackURLKitHandlers() {
        Manager.shared.callbackURLScheme = Manager.urlSchemes?.first

        Manager.shared["fire_event"] = { parameters, success, failure, _ in
            guard let eventName = parameters["eventName"] else {
                failure(XCallbackError.eventNameMissing)
                return
            }

            var cleanParamters = parameters
            cleanParamters.removeValue(forKey: "eventName")
            let eventData = cleanParamters

            Current.api.then { api in
                api.CreateEvent(eventType: eventName, eventData: eventData)
            }.done { _ in
                success(nil)
            }.catch { error -> Void in
                Current.Log.error("Received error from createEvent during X-Callback-URL call: \(error)")
                failure(XCallbackError.generalError)
            }
        }

        Manager.shared["call_service"] = { parameters, success, failure, _ in
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

            Current.api.then { api in
                api.CallService(domain: serviceDomain, service: serviceName, serviceData: serviceData)
            }.done { _ in
                success(nil)
            }.catch { error in
                Current.Log.error("Received error from callService during X-Callback-URL call: \(error)")
                failure(XCallbackError.generalError)
            }
        }

        Manager.shared["send_location"] = { _, success, failure, _ in
            Current.api.then { api in
                api.GetAndSendLocation(trigger: .XCallbackURL)
            }.done { _ in
                success(nil)
            }.catch { error in
                Current.Log.error("Received error from getAndSendLocation during X-Callback-URL call: \(error)")
                failure(XCallbackError.generalError)
            }
        }

        Manager.shared["render_template"] = { parameters, success, failure, _ in
            guard let template = parameters["template"] else {
                failure(XCallbackError.templateMissing)
                return
            }

            var cleanParamters = parameters
            cleanParamters.removeValue(forKey: "template")
            let variablesDict = cleanParamters

            Current.api.then { api in
                api.RenderTemplate(templateStr: template, variables: variablesDict)
            }.done { rendered in
                success(["rendered": String(describing: rendered)])
            }.catch { error in
                Current.Log.error("Received error from RenderTemplate during X-Callback-URL call: \(error)")
                failure(XCallbackError.generalError)
            }
        }
    }

    private func fireEventURLHandler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://fire_event/custom_event?entity_id=device_tracker.entity

        Current.api.then { api in
            api.CreateEvent(eventType: url.pathComponents[1], eventData: serviceData)
        }.done { _ in
            self.showAlert(title: L10n.UrlHandler.FireEvent.Success.title,
                           message: L10n.UrlHandler.FireEvent.Success.message(url.pathComponents[1]))
        }.catch { error -> Void in
            self.showAlert(title: L10n.errorLabel,
                           message: L10n.UrlHandler.FireEvent.Error.message(url.pathComponents[1],
                                                                            error.localizedDescription))
        }
    }

    private func callServiceURLHandler(_ url: URL, _ serviceData: [String: String]) {
        // homeassistant://call_service/device_tracker.see?entity_id=device_tracker.entity
        let domain = url.pathComponents[1].components(separatedBy: ".")[0]
        let service = url.pathComponents[1].components(separatedBy: ".")[1]

        Current.api.then { api in
            api.CallService(domain: domain, service: service, serviceData: serviceData)
        }.done { _ in
            self.showAlert(title: L10n.UrlHandler.CallService.Success.title,
                           message: L10n.UrlHandler.CallService.Success.message(url.pathComponents[1]))
        }.catch { error in
            self.showAlert(title: L10n.errorLabel,
                           message: L10n.UrlHandler.CallService.Error.message(url.pathComponents[1],
                                                                              error.localizedDescription))
        }
    }

    private func sendLocationURLHandler() {
        // homeassistant://send_location/
        Current.api.then { api in
            api.GetAndSendLocation(trigger: .URLScheme)
        }.done { _ in
            self.showAlert(title: L10n.UrlHandler.SendLocation.Success.title,
                           message: L10n.UrlHandler.SendLocation.Success.message)
        }.catch { error in
            self.showAlert(title: L10n.errorLabel,
                           message: L10n.UrlHandler.SendLocation.Error.message(error.localizedDescription))
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

        guard let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID) else {
            Current.sceneManager
                .showFullScreenConfirm(icon: .alertCircleIcon, text: L10n.UrlHandler.Error.actionNotFound)
            return
        }

        Current.sceneManager
            .showFullScreenConfirm(icon: MaterialDesignIcons(named: action.IconName), text: action.Text)

        Current.api.then { api in
            api.HandleAction(actionID: actionID, source: source)
        }.cauterize()
    }
}
