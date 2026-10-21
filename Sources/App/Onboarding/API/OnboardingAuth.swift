import Alamofire
import Foundation
import HAKit
import PromiseKit
import Shared

class OnboardingAuth {
    /// What onboarding wrote over when it persisted the server, for undoing it.
    private struct Persisted {
        var identifier: Identifier<Server>
        var previousInfo: ServerInfo?
        var previousRegistration: RegistrationRecord
    }

    var login: OnboardingAuthLogin = OnboardingAuthLoginImpl()
    var tokenExchange: OnboardingAuthTokenExchange = OnboardingAuthTokenExchangeImpl()
    var preSteps: [OnboardingAuthPreStep.Type] = [
        OnboardingAuthStepClientCertificate.self,
        OnboardingAuthStepConnectivity.self,
    ]
    var postSteps: [OnboardingAuthPostStep.Type] = [
        OnboardingAuthStepDeviceNaming.self,
        OnboardingAuthStepConfig.self,
        OnboardingAuthStepServerIdentity.self,
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
            var persisted: Persisted?
            // Registering records what it made under the identifier onboarding started with, which can be the
            // identifier of a server the app already has.
            let registrationBeforeOnboarding = Current.settingsStore.registrationRecord(for: api.server.identifier)

            return firstly {
                steps(.beforeRegister, .register, .afterRegister)
            }.map { () -> Server in
                // `get_config` ran in `.afterRegister`, so by now the server reports its own
                // instance ID and the identifier can be the one every onboarding route agrees on.
                // When `OnboardingAuthStepServerIdentity` had to ask, the answer it left names the
                // exact server to store under, so the saved servers changing in the meantime can't
                // retarget it.
                let identifier = presenter.resolvedServerIdentifier ?? Self.serverIdentity(
                    for: api.server.info,
                    fallback: api.server.identifier,
                    existingServers: Current.servers.all
                ).storedIdentifier
                let existing = Current.servers.server(for: identifier)
                let existingInfo = existing?.info
                let settings = Current.settingsStore
                persisted = Persisted(
                    identifier: identifier,
                    previousInfo: existingInfo,
                    previousRegistration: identifier == api.server.identifier
                        ? registrationBeforeOnboarding
                        : settings.registrationRecord(for: identifier)
                )

                // Re-authenticating a server the app already has is not a new server, and the
                // privacy step is not shown for it, so it keeps the choices it already carries
                // instead of the holdback above (or a default) overwriting them.
                var serverInfo = api.server.info
                var registration = settings.registrationRecord(for: api.server.identifier)
                if let existing, let existingInfo {
                    serverInfo.setSetting(value: existingInfo.setting(for: .sensorPrivacy), for: .sensorPrivacy)
                    serverInfo.setSetting(value: existingInfo.setting(for: .locationPrivacy), for: .locationPrivacy)

                    if let kept = Self.registrationToKeep(of: existing, insteadOf: registration) {
                        Current.Log.info(
                            "keeping the registration \(existing.identifier) has; the one just made is left behind"
                        )
                        serverInfo.connection.webhookID = existingInfo.connection.webhookID
                        serverInfo.connection.webhookSecret = existingInfo.connection.webhookSecret
                        serverInfo.connection.cloudhookURL = existingInfo.connection.cloudhookURL
                        serverInfo.hassDeviceId = existingInfo.hassDeviceId
                        let keys: [ServerSettingKey<String?>] = [
                            .registeredDeviceID,
                            .registeredDeviceName,
                            .overrideDeviceName,
                        ]
                        for key in keys {
                            serverInfo.setSetting(value: existingInfo.setting(for: key), for: key)
                        }
                        registration = kept
                    }
                }

                // The registration belongs to the server as it is persisted.
                settings.setRegistrationRecord(registration, for: identifier)
                if identifier != api.server.identifier {
                    settings.setRegistrationRecord(registrationBeforeOnboarding, for: api.server.identifier)
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
                let settings = Current.settingsStore
                let attempt = settings.registrationRecord(for: api.server.identifier)
                // An identifier onboarding made up for an address typed in is not used again, so keeps nothing.
                settings.setRegistrationRecord(
                    Self.knowsInstance(of: api.server)
                        ? Self.rollingBack(to: registrationBeforeOnboarding, from: attempt)
                        : registrationBeforeOnboarding,
                    for: api.server.identifier
                )
                return when(resolved: undoConfigure(api: api, persisted: persisted))
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

                    let identifier = Self.onboardingIdentifier(for: instance, existingServers: Current.servers.all)
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

    /// The identifier the detached onboarding server carries until it is persisted. Work keyed by it
    /// during onboarding (cached APIs, notification categories, sensors) writes under it, so it is
    /// never the identifier of a saved server at another address: an instance discovered over mDNS
    /// with a cloned instance ID would otherwise write into the original server's data.
    static func onboardingIdentifier(
        for instance: DiscoveredHomeAssistant,
        existingServers: [Server]
    ) -> Identifier<Server> {
        let candidate = Identifier<Server>(rawValue: instance.uuid ?? UUID().uuidString)
        guard let existing = existingServers.first(where: { $0.identifier == candidate }) else {
            return candidate
        }

        let addresses = URL.hostAndPortIdentities(of: [instance.internalURL ?? instance.externalURL])
        if !existing.info.connection.hostAndPortIdentities.isDisjoint(with: addresses) {
            return candidate
        }

        return Identifier<Server>(rawValue: "\(DiscoveredHomeAssistant.autogeneratedUUIDPrefix)\(UUID().uuidString)")
    }

    /// Where an onboarded server belongs among the servers the app already has, and so which
    /// identifier it is stored under. Keeping an existing server's identifier matters because
    /// widgets, shortcuts and Siri configurations hold that string in stores this app cannot
    /// rewrite, so re-onboarding a server the app already has updates it in place rather than
    /// renaming it.
    ///
    /// The instance ID is evidence of that rather than proof: a server set up from another one's
    /// backup reports the other's ID. So the ID has to agree with the address onboarding signed in
    /// through, the only one known to reach this server (a restored copy can still advertise the
    /// original's other URLs). An existing server with the same ID configured at that `host:port` is
    /// the same server; one configured elsewhere is `ambiguous`, and the user says which it is. An
    /// address alone proves nothing, since separate homes often share `homeassistant.local`, so a
    /// server reporting another ID is new: stored under its instance ID when no existing server
    /// already uses that string as its identifier, else under the fallback onboarding started with.
    static func serverIdentity(
        for serverInfo: ServerInfo,
        fallback: Identifier<Server>,
        existingServers: [Server]
    ) -> OnboardingServerIdentity {
        let addresses = URL.hostAndPortIdentities(of: [OnboardingAuthStepConfig.signedInURL(of: serverInfo.connection)])
        func sharesAnAddress(_ server: Server) -> Bool {
            !server.info.connection.hostAndPortIdentities.isDisjoint(with: addresses)
        }

        guard let instanceID = serverInfo.instanceID, !instanceID.isEmpty else {
            return .new(fallback)
        }

        let sameInstanceID = existingServers.filter { $0.info.instanceID == instanceID }
        if let sameServer = sameInstanceID.first(where: sharesAnAddress) {
            return .existing(sameServer.identifier)
        }
        if let clone = sameInstanceID.first {
            return .ambiguous(
                existing: clone,
                separateIdentifier: unusedIdentifier(preferring: [fallback], among: existingServers)
            )
        }

        return .new(unusedIdentifier(
            preferring: [Identifier<Server>(rawValue: instanceID), fallback],
            among: existingServers
        ))
    }

    /// The first of `candidates` no existing server is stored under, else a freshly minted one.
    private static func unusedIdentifier(
        preferring candidates: [Identifier<Server>],
        among existingServers: [Server]
    ) -> Identifier<Server> {
        let taken = Set(existingServers.map(\.identifier))
        return candidates.first { !taken.contains($0) } ?? Identifier<Server>(rawValue: UUID().uuidString)
    }

    /// Whether onboarding knows which Home Assistant `server` is, from the instance ID it was discovered with.
    static func knowsInstance(of server: Server) -> Bool {
        !server.identifier.rawValue.hasPrefix(DiscoveredHomeAssistant.autogeneratedUUIDPrefix)
    }

    /// The servers the app already has that onboarding reached again, as far as it can tell before registering. A
    /// server discovered with its instance ID is the one with that ID. One reached by an address typed in can be any
    /// server answering there, such as either of two homes at `homeassistant.local:8123`, so it is none of them until
    /// registering tells.
    static func existingServers(reachedBy server: Server, among servers: [Server]) -> [Server] {
        guard knowsInstance(of: server) else { return [] }
        return servers.filter { $0.identifier == server.identifier || $0.info.instanceID == server.identifier.rawValue }
    }

    /// The registration `existing` already has, when it is this device's own and `registration`, which onboarding
    /// just made, is under another identity: a server reached by an address typed in is only told apart from the
    /// servers the app has once it is registered with, and the registration it had keeps its Home Assistant device
    /// and everything that points at it. `nil` when the registration just made is the one to keep, which is also the
    /// case when `existing` has no webhook to reach its registration with, as after recovering its credentials.
    static func registrationToKeep(
        of existing: Server,
        insteadOf registration: RegistrationRecord
    ) -> RegistrationRecord? {
        let identity = Current.settingsStore.currentRegistrationIdentity(for: existing)
        guard !existing.info.connection.webhookID.isEmpty,
              let vendorID = Current.device.identifierForVendor(), identity.ownerVendorID == vendorID,
              let made = registration.current, made.deviceID != identity.deviceID else { return nil }
        return RegistrationRecord(current: identity)
    }

    /// `previous`, keeping as the identity to register with next the one this device registered under in `attempt`, or
    /// was about to: the server can have that registration even though onboarding failed, such as when its response
    /// was lost, and trying again then registers under it rather than adding another device.
    private static func rollingBack(
        to previous: RegistrationRecord,
        from attempt: RegistrationRecord
    ) -> RegistrationRecord {
        guard let vendorID = Current.device.identifierForVendor(), let identity = attempt.pending ?? attempt.current,
              identity.ownerVendorID == vendorID, identity != previous.current else { return previous }
        var record = previous
        record.pending = identity
        return record
    }

    private func undoConfigure(
        api: HomeAssistantAPI,
        persisted: Persisted?
    ) -> Promise<Void> {
        Current.Log.info()

        guard let persisted else {
            // Nothing to roll back, so the flow doesn't wait for a revocation that can run until timeout.
            api.tokenManager.revokeToken().ensure { withExtendedLifetime(api) {} }.cauterize()
            api.connection.disconnect()
            // Webhooks sent during onboarding cache an API for the unsaved server; drop only that.
            let identifier = api.server.identifier
            if Current.cachedApis[identifier]?.server === api.server {
                Current.resetAPICache(for: [identifier])
            }
            return .value(())
        }

        let identifier = persisted.identifier
        return firstly {
            when(resolved: api.tokenManager.revokeToken()).asVoid()
        }.done {
            api.connection.disconnect()

            if let previousInfo = persisted.previousInfo {
                // This onboarding overwrote a server the user already had, so put it back instead
                // of deleting it along with everything keyed to its identifier.
                Current.servers.add(identifier: identifier, serverInfo: previousInfo)
            } else {
                Current.servers.remove(identifier: identifier)
            }
            let settings = Current.settingsStore
            let attempt = settings.registrationRecord(for: identifier)
            settings.setRegistrationRecord(
                Self.rollingBack(to: persisted.previousRegistration, from: attempt),
                for: identifier
            )

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
