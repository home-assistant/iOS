import Alamofire
import Foundation
import HAKit
import PromiseKit
import Shared

class OnboardingAuth {
    var login: OnboardingAuthLogin = OnboardingAuthLoginImpl()
    var tokenExchange: OnboardingAuthTokenExchange = OnboardingAuthTokenExchangeImpl()
    var preSteps: [OnboardingAuthPreStep.Type] = [
        OnboardingAuthStepClientCertificate.self,
        OnboardingAuthStepConnectivity.self,
    ]
    var postSteps: [OnboardingAuthPostStep.Type] = [
        OnboardingAuthStepDeviceNaming.self,
        OnboardingAuthStepConfig.self,
        OnboardingAuthStepSensors.self,
        OnboardingAuthStepModels.self,
        OnboardingAuthStepRegister.self,
        OnboardingAuthStepNotify.self,
    ]

    func authenticate(
        to startInstance: DiscoveredHomeAssistant,
        presenter: OnboardingAuthPresenter
    ) -> Promise<Server> {
        firstly {
            connect(to: startInstance, presenter: presenter)
        }.then { [self] api -> Promise<Server> in
            func steps(_ steps: OnboardingAuthStepPoint...) -> Promise<Void> {
                var promise: Promise<Void> = .value(())

                for step in steps {
                    promise = promise.then { [self] in
                        performPostSteps(checkPoint: step, api: api, presenter: presenter)
                    }
                }

                return promise
            }

            // A server added next to an existing one is asked what it should receive at the end of
            // onboarding (`OnboardingPrivacyView`), so it starts out sending nothing: the steps
            // below would otherwise hand a system nobody has been asked about this device's exact
            // location and every sensor the user switched on for another one. Abandoning the flow
            // before the question is answered leaves it on these values rather than the defaults.
            if !Current.servers.all.isEmpty {
                api.server.info.setSetting(value: ServerSensorPrivacy.none, for: .sensorPrivacy)
                api.server.info.setSetting(value: ServerLocationPrivacy.never, for: .locationPrivacy)
            }

            // Set once the server is persisted, so a later failure undoes exactly what was written.
            var persisted: (identifier: Identifier<Server>, previousInfo: ServerInfo?)?

            return firstly {
                steps(.beforeRegister, .register, .afterRegister)
            }.map { () -> Server in
                // `get_config` ran in `.afterRegister`, so by now the server reports its own
                // instance ID and the identifier can be the one every onboarding route agrees on.
                let identifier = Self.serverIdentifier(
                    for: api.server.info,
                    fallback: api.server.identifier,
                    existingServers: Current.servers.all
                )
                let existingInfo = Current.servers.server(for: identifier)?.info
                persisted = (identifier, existingInfo)

                // Re-authenticating a server the app already has is not a new server, and the
                // privacy step is not shown for it, so it keeps the choices it already carries
                // instead of the holdback above (or a default) overwriting them.
                var serverInfo = api.server.info
                if let existingInfo {
                    serverInfo.setSetting(value: existingInfo.setting(for: .sensorPrivacy), for: .sensorPrivacy)
                    serverInfo.setSetting(value: existingInfo.setting(for: .locationPrivacy), for: .locationPrivacy)
                }

                // actually persists to outside-onboarding
                return Current.servers.add(identifier: identifier, serverInfo: serverInfo)
            }.get { server in
                // Nothing was persisted yet when `configuredAPI` ran, so the API it returned is built
                // around a detached, in-memory `Server` — and everything that API created at init
                // captured that instance: the token manager, the websocket's connection-info and
                // token closures, the request adapters. Handing `api.server` the keychain-persisted
                // server cannot reach any of them, so they keep reading the onboarding-time snapshot
                // for the rest of the session. A later re-authentication then writes its new token to
                // the persisted server while this API keeps presenting the superseded one, which Home
                // Assistant answers with `auth: invalid` / 401 until the app is relaunched. Replace it
                // with an API built on the persisted server, and drop the onboarding connection so the
                // session doesn't keep two.
                api.connection.disconnect()
                Current.setCachedApi(HomeAssistantAPI(server: server), for: server.identifier)
            }.then { server in
                steps(.complete).map { server }
            }.recover(policy: .allErrors) { [self] error -> Promise<Server> in
                when(resolved: undoConfigure(api: api, persisted: persisted))
                    .then { _ in Promise<Server>(error: error) }
            }
        }
    }

    private func perform(checkPoint: OnboardingAuthStepPoint, checks: [OnboardingAuthStep]) -> Promise<Void> {
        // Execute steps sequentially to allow ClientCertificate to complete before Connectivity
        checks.reduce(Promise.value(())) { promise, check in
            promise.then {
                check.perform(point: checkPoint).tap { result in
                    Current.Log.info("\(type(of: check)): \(result)")
                }.asVoid()
            }
        }
    }

    private func performPreSteps(
        checkPoint: OnboardingAuthStepPoint,
        authDetails: OnboardingAuthDetails,
        presenter: OnboardingAuthPresenter
    ) -> Promise<Void> {
        Current.Log.info(checkPoint)
        return perform(checkPoint: checkPoint, checks: preSteps.compactMap { checkType in
            if checkType.supportedPoints.contains(checkPoint) {
                return checkType.init(authDetails: authDetails, presenter: presenter)
            } else {
                return nil
            }
        })
    }

    private func performPostSteps(
        checkPoint: OnboardingAuthStepPoint,
        api: HomeAssistantAPI,
        presenter: OnboardingAuthPresenter
    ) -> Promise<Void> {
        Current.Log.info(checkPoint)
        return perform(checkPoint: checkPoint, checks: postSteps.compactMap { checkType in
            if checkType.supportedPoints.contains(checkPoint) {
                return checkType.init(api: api, presenter: presenter)
            } else {
                return nil
            }
        })
    }

    private func connect(
        to baseInstance: DiscoveredHomeAssistant,
        presenter: OnboardingAuthPresenter
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
                    performPreSteps(checkPoint: .beforeAuth, authDetails: authDetails, presenter: presenter)
                }.then { [self] in
                    login.open(authDetails: authDetails, presenter: presenter)
                }.then { [self] result -> Promise<HomeAssistantAPI> in
                    // The login web view may have been redirected to a different port/scheme; adopt that
                    // address so the stored server URL (and the token exchange) target the real server.
                    let adoptedInstance = Self.instance(
                        instance,
                        adoptingResolvedURL: result.resolvedURL,
                        attemptedURL: url
                    )
                    return configuredAPI(authDetails: authDetails, instance: adoptedInstance, code: result.code)
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

    /// When the login web view ends on a different URL than the one we started with, adopt that address
    /// for the slot (internal/external) we attempted. Only same-host port/scheme redirects are adopted —
    /// a different host is ignored so we never follow an unexpected server.
    static func instance(
        _ instance: DiscoveredHomeAssistant,
        adoptingResolvedURL resolvedURL: URL?,
        attemptedURL: URL
    ) -> DiscoveredHomeAssistant {
        let attemptedBase = attemptedURL.serverBaseURL()

        guard let adoptedBase = resolvedURL?.sameHostRedirectBaseURL(from: attemptedURL) else {
            if let resolvedBase = resolvedURL?.serverBaseURL(), !resolvedBase.baseIsEqual(to: attemptedBase) {
                // Different host, or an https->http downgrade we won't follow.
                Current.Log.warning("Not adopting auth redirect to \(resolvedBase); keeping \(attemptedBase)")
            }
            return instance
        }

        Current.Log.info("Adopting redirected server URL \(adoptedBase) (was \(attemptedBase))")

        return with(instance) {
            if let url = $0.internalURL, url.serverBaseURL().baseIsEqual(to: attemptedBase) {
                $0.internalURL = adoptedBase
            }
            if let url = $0.externalURL, url.serverBaseURL().baseIsEqual(to: attemptedBase) {
                $0.externalURL = adoptedBase
            }
            $0.internalOrExternalURL = $0.internalURL ?? $0.externalURL ?? adoptedBase
        }
    }

    private func configuredAPI(
        authDetails: OnboardingAuthDetails,
        instance: DiscoveredHomeAssistant,
        code: String
    ) -> Promise<HomeAssistantAPI> {
        Current.Log.info()

        return Promise { seal in
            Task { [self] in
                do {
                    var connectionInfo = ConnectionInfo(
                        discovered: instance,
                        authDetails: authDetails
                    )

                    let tokenInfo = try await tokenExchange.tokenInfo(
                        code: code,
                        connectionInfo: &connectionInfo
                    )

                    Current.Log.verbose()

                    var serverInfo = ServerInfo(
                        name: ServerInfo.defaultName,
                        connection: connectionInfo,
                        token: tokenInfo,
                        version: instance.version ?? DiscoveredHomeAssistant.defaultVersion
                    )

                    let identifier = Identifier<Server>(rawValue: instance.uuid ?? UUID().uuidString)
                    let server = Server(
                        identifier: identifier,
                        getter: { serverInfo },
                        setter: { serverInfo = $0; return true }
                    )

                    seal.fulfill(HomeAssistantAPI(server: server))
                } catch {
                    seal.reject(error)
                }
            }
        }
    }

    /// The identifier an onboarded server is stored under: the identifier of a server already
    /// reporting this instance ID, else the instance ID itself, else the fallback onboarding
    /// started with. Keeping an existing server's identifier matters because widgets, shortcuts
    /// and Siri configurations hold that string in stores this app cannot rewrite, so re-onboarding
    /// a server the app already has updates it in place rather than renaming it.
    static func serverIdentifier(
        for serverInfo: ServerInfo,
        fallback: Identifier<Server>,
        existingServers: [Server]
    ) -> Identifier<Server> {
        guard let instanceID = serverInfo.instanceID, !instanceID.isEmpty else {
            return fallback
        }

        if let existing = existingServers.first(where: { $0.info.instanceID == instanceID }) {
            return existing.identifier
        }

        return Identifier<Server>(rawValue: instanceID)
    }

    private func undoConfigure(
        api: HomeAssistantAPI,
        persisted: (identifier: Identifier<Server>, previousInfo: ServerInfo?)?
    ) -> Promise<Void> {
        Current.Log.info()
        let identifier = persisted?.identifier ?? api.server.identifier
        return firstly {
            when(resolved: api.tokenManager.revokeToken()).asVoid()
        }.done {
            api.connection.disconnect()

            if let previousInfo = persisted?.previousInfo {
                // This onboarding overwrote a server the user already had, so put it back instead
                // of deleting it along with everything keyed to its identifier.
                Current.servers.add(identifier: identifier, serverInfo: previousInfo)
            } else {
                Current.servers.remove(identifier: identifier)
            }

            Current.resetAPICache(for: [identifier])
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
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: authDetails.exceptions,
            connectionAccessSecurityLevel: .undefined,
            clientCertificate: authDetails.clientCertificate
        )

        // default cloud to on
        useCloud = true

        if discovered.internalURL != nil, discovered.externalURL != nil {
            overrideActiveURLType = .internal
        }
    }
}
