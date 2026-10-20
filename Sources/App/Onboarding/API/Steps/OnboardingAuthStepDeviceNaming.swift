import HAKit
import HAKit_PromiseKit
import PromiseKit
import Shared

private struct RegisteredDevice {
    var name: String
    var id: String

    init?(data: HAData) throws {
        self.name = try data.decode("name")
        self.id = try {
            let identifiers: [[String]] = try data.decode("identifiers")
            for identifier in identifiers where identifier.count == 2 && identifier.starts(with: ["mobile_app"]) {
                return identifier[1]
            }

            throw HADataError.couldntTransform(key: "identifiers")
        }()
    }

    func matches(name other: String) -> Bool {
        name.lowercased() == other.lowercased()
    }
}

struct OnboardingAuthStepDeviceNaming: OnboardingAuthPostStep {
    init(
        api: HomeAssistantAPI,
        presenter: OnboardingAuthPresenter
    ) {
        self.api = api
        self.presenter = presenter
    }

    var api: HomeAssistantAPI
    var presenter: OnboardingAuthPresenter

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.beforeRegister])
    }

    var timeout: TimeInterval = 30.0

    /// Whether the user has already been prompted for a device name.
    static var firstUserDeviceNameInput = true

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        fetchDeviceListWithTimeout().then { [self] registeredDevices -> Promise<Void> in
            if reuseRegistrationOfExistingServer(among: registeredDevices) {
                return .value(())
            }
            leaveRegistrationOfAnotherDevice()

            let deviceID = Current.settingsStore.registrationIdentity(for: api.server).deviceID
            guard !registeredDevices.contains(where: { $0.id == deviceID }) else {
                // if the integration is registered already, we will take over that one, so we don't need to look
                return .value(())
            }

            // this can be removed once the mobile_app notify service stops being device name specific
            return promptForDeviceName(
                deviceName: Current.device.deviceName(),
                registeredDevices: registeredDevices
            )
        }
    }

    private func promptForDeviceName(
        deviceName: String,
        registeredDevices: [RegisteredDevice]
    ) -> Promise<Void> {
        guard registeredDevices.contains(where: { $0.matches(name: deviceName) }) ||
            OnboardingAuthStepDeviceNaming.firstUserDeviceNameInput else {
            // if the device name is not already taken, we can safely use it and don't need to prompt
            return .value(())
        }
        OnboardingAuthStepDeviceNaming.firstUserDeviceNameInput = false

        return Promise<Void> { seal in
            let request = OnboardingDeviceNameRequest(onSave: { name, request in
                guard name.isEmpty == false else {
                    request.fail(with: L10n.Onboarding.DeviceNameCheck.Error.title(deviceName))
                    return
                }

                // Fetch updated device list to ensure we have current data
                fetchDeviceListWithTimeout().done { updatedDevices in
                    if updatedDevices.contains(where: { $0.matches(name: name) }) {
                        // Name conflicts with a registered device; keep the screen up with an inline error
                        request.fail(with: L10n.Onboarding.DeviceNameCheck.Error.title(name))
                    } else {
                        // No conflict, proceed with the name. The screen stays pushed (showing its
                        // saving indicator) until the flow replaces it with the next step.
                        api.server.info.setSetting(value: name, for: .overrideDeviceName)
                        resetFirstUserDeviceNameInput()
                        request.finish()
                        seal.fulfill(())
                    }
                }.catch { _ in
                    // If we can't verify the name is free, keep the screen up with an inline error
                    request.fail(with: L10n.Onboarding.DeviceNameCheck.Error.unreachable)
                }
            }, onCancel: {
                resetFirstUserDeviceNameInput()
                seal.reject(PMKError.cancelled)
            })

            presenter.push(.deviceName(request))
        }
    }

    /// Signing in again to a server the app already has keeps the device it has there, under the identity it was
    /// registered with and the name the server knows it by, rather than adding a device. Returns whether that device
    /// is there to take over, which needs no name checked.
    ///
    /// Only a server discovered with its instance ID is known to be one the app has before registering: taking a
    /// device for a server it isn't, such as another home answering at the same address, would take over the
    /// registration another device has there. A server known by its instance ID keeps its identity even where its
    /// device is gone, such as after restoring an older backup of Home Assistant: it is registered again under that
    /// identity. A registration another device owns is left to it either way.
    private func reuseRegistrationOfExistingServer(among registeredDevices: [RegisteredDevice]) -> Bool {
        let settings = Current.settingsStore
        let ownership = RegistrationOwnership()
        let candidates = OnboardingAuth.existingServers(reachedBy: api.server, among: Current.servers.all).filter {
            !ownership.belongsToAnotherDevice(settings.registrationIdentity(for: $0))
        }
        let matches = registrations(of: candidates, among: registeredDevices)

        // A server saved more than once can share an identity, which is one device on this server either way.
        if matches.count == 1, let match = matches.first {
            adopt(registrationOf: match.value.server, named: match.value.device.name)
            return true
        }
        if let existing = candidates.first {
            adopt(registrationOf: existing, named: existing.info.setting(for: .overrideDeviceName))
        }
        return false
    }

    /// The identities `servers` are registered with that this server has a device for, with a server registered
    /// under each.
    private func registrations(
        of servers: [Server],
        among registeredDevices: [RegisteredDevice]
    ) -> [RegistrationIdentity: (server: Server, device: RegisteredDevice)] {
        var registrations = [RegistrationIdentity: (server: Server, device: RegisteredDevice)]()
        for server in servers {
            let identity = Current.settingsStore.registrationIdentity(for: server)
            if let device = registeredDevices.first(where: { $0.id == identity.deviceID }) {
                registrations[identity] = (server, device)
            }
        }
        return registrations
    }

    /// Registering under an identity another device owns would take over that device's registration, such as when
    /// signing in again to a server a backup brought along before settling it, or while the identifier this device
    /// registers with by default is still the other device's. This device registers under one of its own instead.
    ///
    /// Without a registration of its own here, this device registers with its default identifier, which a saved server
    /// can record as another device's: keeping one server's registration makes the identifier this device's, while
    /// another server the backup brought can still be the other device's under it, and this server can be that one.
    private func leaveRegistrationOfAnotherDevice() {
        let settings = Current.settingsStore
        let ownership = RegistrationOwnership()
        let identity = settings.registrationIdentity(for: api.server)
        let isDefault = settings.registrationRecord(for: api.server.identifier) == RegistrationRecord()
        let isAnotherDevicesElsewhere = isDefault && Current.servers.all.contains { server in
            let saved = settings.registrationIdentity(for: server)
            return saved.deviceID == identity.deviceID && ownership.belongsToAnotherDevice(saved)
        }
        if ownership.belongsToAnotherDevice(identity) || isAnotherDevicesElsewhere {
            registerUnderAnIdentityOfItsOwn()
        }
    }

    /// Registers this device under a new identity of its own, as registering it anew does.
    private func registerUnderAnIdentityOfItsOwn() {
        guard let vendorID = Current.device.identifierForVendor() else { return }
        let settings = Current.settingsStore
        settings.updateRegistrationRecord(for: api.server.identifier) { record in
            record.pending = RegistrationIdentity(deviceID: settings.newIntegrationDeviceID(), ownerVendorID: vendorID)
        }
    }

    /// Takes on the registration `server` has, under the name it knows this device by. An identity `server` is still
    /// to register under stays one to register under: until registering under it succeeds, the credentials `server`
    /// has are for the registration it has, which can be another device's.
    private func adopt(registrationOf server: Server, named name: String?) {
        let settings = Current.settingsStore
        let current = settings.currentRegistrationIdentity(for: server)
        let next = settings.registrationIdentity(for: server)
        settings.setRegistrationRecord(
            RegistrationRecord(current: current, pending: next == current ? nil : next),
            for: api.server.identifier
        )
        guard api.server.info.setting(for: .overrideDeviceName) == nil, let name,
              name != api.server.info.mobileAppDeviceName else { return }
        api.server.info.setSetting(value: name, for: .overrideDeviceName)
    }

    // In case the flow is completed or cancelled, we reset the first user device name input flag.
    private func resetFirstUserDeviceNameInput() {
        OnboardingAuthStepDeviceNaming.firstUserDeviceNameInput = true
    }

    /// Fetches the device list, failing after `timeout` instead of waiting indefinitely for a
    /// websocket that may never answer.
    private func fetchDeviceListWithTimeout() -> Promise<[RegisteredDevice]> {
        let timeout: Promise<[RegisteredDevice]> = after(seconds: timeout).then { () -> Promise<[RegisteredDevice]> in
            switch api.connection.state {
            case let .disconnected(reason: .waitingToReconnect(lastError: .some(error), atLatest: _, retryCount: _)):
                throw error
            default:
                throw OnboardingAuthError(kind: .invalidURL, data: nil)
            }
        }

        // racing the request, not the whole flow, importantly.
        // otherwise we'd fail out before the user finished typing.
        return race(timeout, fetchDeviceList())
    }

    private func fetchDeviceList() -> Promise<[RegisteredDevice]> {
        firstly { () -> Promise<[HAData]> in
            api.connection.send(.init(type: "config/device_registry/list")).promise.compactMap {
                if case let .array(value) = $0 {
                    return value
                } else {
                    throw HomeAssistantAPI.APIError.invalidResponse
                }
            }
        }.compactMapValues { value -> RegisteredDevice? in
            try? RegisteredDevice(data: value)
        }
    }
}
