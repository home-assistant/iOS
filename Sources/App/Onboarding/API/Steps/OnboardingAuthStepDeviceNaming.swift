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

    /// Signing in to a server the app already has again keeps the device it has there, under the identity and name
    /// it was registered with, rather than adding a device or taking over one left to another device. Only the
    /// server's own devices tell whether it is that server: a server reached by an address typed in only reports
    /// which one it is once registered, and another one can answer at the same address.
    private func reuseRegistrationOfExistingServer(among registeredDevices: [RegisteredDevice]) -> Bool {
        guard let existing = OnboardingAuth.existingServer(reachedBy: api.server, among: Current.servers.all) else {
            return false
        }
        let identity = Current.settingsStore.registrationIdentity(for: existing)
        guard registeredDevices.contains(where: { $0.id == identity.deviceID }) else { return false }

        Current.settingsStore.setRegistrationRecord(RegistrationRecord(current: identity), for: api.server.identifier)
        if api.server.info.setting(for: .overrideDeviceName) == nil,
           let name = existing.info.setting(for: .overrideDeviceName) {
            api.server.info.setSetting(value: name, for: .overrideDeviceName)
        }
        return true
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
