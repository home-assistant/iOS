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

    private func reuseRegistrationOfExistingServer(among registeredDevices: [RegisteredDevice]) -> Bool {
        let settings = Current.settingsStore
        let ownership = RegistrationOwnership()
        let candidates = OnboardingAuth.existingServers(reachedBy: api.server, among: Current.servers.all).filter {
            !ownership.belongsToAnotherDevice(settings.registrationIdentity(for: $0))
        }
        let matches = registrations(of: candidates, among: registeredDevices)

        if matches.count == 1, let match = matches.first {
            adopt(registrationOf: match.value.server, named: match.value.device.name)
            return true
        }
        if let existing = candidates.first {
            adopt(registrationOf: existing, named: existing.info.setting(for: .overrideDeviceName))
        }
        return false
    }

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

    private func registerUnderAnIdentityOfItsOwn() {
        guard let vendorID = Current.device.identifierForVendor() else { return }
        let settings = Current.settingsStore
        settings.updateRegistrationRecord(for: api.server.identifier) { record in
            record.pending = RegistrationIdentity(deviceID: settings.newIntegrationDeviceID(), ownerVendorID: vendorID)
        }
    }

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
