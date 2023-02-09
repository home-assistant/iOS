import Alamofire
import Foundation
import HAKit
import PromiseKit
import Shared

class OnboardingAuth {
    func successController(server: Server?) -> UIViewController {
        OnboardingPermissionViewControllerFactory.next(server: server)
    }

    func failureController(error: Error) -> UIViewController {
        OnboardingErrorViewController(error: error)
    }

    var login: OnboardingAuthLogin = OnboardingAuthLoginImpl()
    var tokenExchange: OnboardingAuthTokenExchange = OnboardingAuthTokenExchangeImpl()
    var preSteps: [OnboardingAuthPreStep.Type] = [
        OnboardingAuthStepConnectivity.self,
    ]
    var postSteps: [OnboardingAuthPostStep.Type] = [
        OnboardingAuthStepDuplicate.self,
        OnboardingAuthStepConfig.self,
        OnboardingAuthStepSensors.self,
        OnboardingAuthStepModels.self,
        OnboardingAuthStepRegister.self,
        OnboardingAuthStepNotify.self,
    ]

    func authenticate(
        to startInstance: DiscoveredHomeAssistant,
        sender: UIViewController
    ) -> Promise<Server> {
        firstly {
            connect(to: startInstance, sender: sender)
        }.then { [self] api -> Promise<Server> in
            func steps(_ steps: OnboardingAuthStepPoint...) -> Promise<Void> {
                var promise: Promise<Void> = .value(())

                for step in steps {
                    promise = promise.then { [self] in
                        performPostSteps(checkPoint: step, api: api, sender: sender)
                    }
                }

                return promise
            }

            return firstly {
                steps(.beforeRegister, .register, .afterRegister)
            }.map {
                // actually persists to outside-onboarding
                Current.servers.add(identifier: api.server.identifier, serverInfo: api.server.info)
            }.get { server in
                // somewhat necessary so it points to the keychain-persisted version
                api.server = server
                // not super necessary but prevents making a duplicate connection during this session
                Current.cachedApis[api.server.identifier] = api
            }.then { server in
                steps(.complete).map { server }
            }.recover(policy: .allErrors) { [self] error -> Promise<Server> in
                when(resolved: undoConfigure(api: api)).then { _ in Promise<Server>(error: error) }
            }
        }
    }

    private func perform(checkPoint: OnboardingAuthStepPoint, checks: [OnboardingAuthStep]) -> Promise<Void> {
        when(fulfilled: checks.compactMap { check in
            check.perform(point: checkPoint).tap { result in
                Current.Log.info("\(type(of: check)): \(result)")
            }
        }).asVoid()
    }

    private func performPreSteps(
        checkPoint: OnboardingAuthStepPoint,
        authDetails: OnboardingAuthDetails,
        sender: UIViewController
    ) -> Promise<Void> {
        Current.Log.info(checkPoint)
        return perform(checkPoint: checkPoint, checks: preSteps.compactMap { checkType in
            if checkType.supportedPoints.contains(checkPoint) {
                return checkType.init(authDetails: authDetails, sender: sender)
            } else {
                return nil
            }
        })
    }

    private func performPostSteps(
        checkPoint: OnboardingAuthStepPoint,
        api: HomeAssistantAPI,
        sender: UIViewController
    ) -> Promise<Void> {
        Current.Log.info(checkPoint)
        return perform(checkPoint: checkPoint, checks: postSteps.compactMap { checkType in
            if checkType.supportedPoints.contains(checkPoint) {
                return checkType.init(api: api, sender: sender)
            } else {
                return nil
            }
        })
    }

    private func connect(
        to baseInstance: DiscoveredHomeAssistant,
        sender: UIViewController
    ) -> Promise<HomeAssistantAPI> {
        // we prefer internal URL first, if it's available
        var instances = [(URL, DiscoveredHomeAssistant)]()

        if let internalURL = baseInstance.internalURL {
            instances.append((internalURL, baseInstance))
        }

        if let externalURL = baseInstance.externalURL {
            instances.append((externalURL, with(baseInstance) {
                $0.internalURL = nil
            }))
        }

        var promise: Promise<HomeAssistantAPI> = .init(error: OnboardingAuthError(kind: .invalidURL))

        for (idx, (url, instance)) in instances.enumerated() {
            promise = promise.recover { [self] originalError -> Promise<HomeAssistantAPI> in
                let authDetails = try OnboardingAuthDetails(baseURL: url)

                return firstly {
                    performPreSteps(checkPoint: .beforeAuth, authDetails: authDetails, sender: sender)
                }.then { [self] in
                    login.open(authDetails: authDetails, sender: sender)
                }.then { [self] code in
                    configuredAPI(authDetails: authDetails, instance: instance, code: code)
                }.recover { newError -> Promise<HomeAssistantAPI> in
                    if idx == 0 {
                        // we're the first/internal url, so our error should break the placeholder one
                        throw newError
                    } else {
                        // preserve the error we got for the internal url
                        throw originalError
                    }
                }
            }
        }

        return promise
    }

    private func configuredAPI(
        authDetails: OnboardingAuthDetails,
        instance: DiscoveredHomeAssistant,
        code: String
    ) -> Promise<HomeAssistantAPI> {
        Current.Log.info()

        var connectionInfo = ConnectionInfo(discovered: instance, authDetails: authDetails)

        return tokenExchange.tokenInfo(
            code: code,
            connectionInfo: &connectionInfo
        ).then { tokenInfo -> Promise<HomeAssistantAPI> in
            Current.Log.verbose()

            var serverInfo = ServerInfo(
                name: ServerInfo.defaultName,
                connection: connectionInfo,
                token: tokenInfo,
                version: instance.version
            )

            let identifier = Identifier<Server>(rawValue: instance.uuid ?? UUID().uuidString)
            let server = Server(
                identifier: identifier,
                getter: { serverInfo },
                setter: { serverInfo = $0; return true }
            )

            return .value(HomeAssistantAPI(server: server))
        }
    }

    private func undoConfigure(api: HomeAssistantAPI) -> Promise<Void> {
        Current.Log.info()
        return firstly {
            when(resolved: api.tokenManager.revokeToken()).asVoid()
        }.done {
            api.connection.disconnect()
            Current.servers.remove(identifier: api.server.identifier)
        }
    }
}

private extension ConnectionInfo {
    init(discovered: DiscoveredHomeAssistant, authDetails: OnboardingAuthDetails) {
        self.init(
            externalURL: discovered.externalURL,
            internalURL: discovered.internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "",
            webhookSecret: nil,
            internalSSIDs: Current.connectivity.currentWiFiSSID().map { [$0] },
            internalHardwareAddresses: nil,
            isLocalPushEnabled: true,
            securityExceptions: authDetails.exceptions
        )

        // default cloud to on
        useCloud = true

        // if we have internal+external, we're on the internal network doing discovery
        // but we don't yet have location permission to know we're on an internal ssid
        if internalSSIDs == [] || internalSSIDs == nil,
           discovered.internalURL != nil, discovered.externalURL != nil {
            overrideActiveURLType = .internal
        }
    }
}
