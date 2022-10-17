import HAKit
import PromiseKit
import Shared

struct OnboardingAuthStepDuplicate: OnboardingAuthPostStep {
    init(
        api: HomeAssistantAPI,
        sender: UIViewController
    ) {
        self.api = api
        self.sender = sender
    }

    var api: HomeAssistantAPI
    var sender: UIViewController

    static var supportedPoints: Set<OnboardingAuthStepPoint> {
        Set([.beforeRegister])
    }

    var timeout: TimeInterval = 30.0

    func perform(point: OnboardingAuthStepPoint) -> Promise<Void> {
        let devices = firstly { () -> Promise<[HAData]> in
            api.connection.send(.init(type: "config/device_registry/list")).promise.map {
                if case let .array(value) = $0 {
                    return value
                } else {
                    throw HomeAssistantAPI.APIError.invalidResponse
                }
            }
        }.compactMapValues { value -> RegisteredDevice? in
            try? RegisteredDevice(data: value)
        }

        let timeout: Promise<[RegisteredDevice]> = after(seconds: timeout).then { () -> Promise<[RegisteredDevice]> in
            switch api.connection.state {
            case let .disconnected(reason: .waitingToReconnect(lastError: .some(error), atLatest: _, retryCount: _)):
                throw error
            default:
                throw OnboardingAuthError(kind: .invalidURL, data: nil)
            }
        }

        // racing the request, not the whole flow, importantly.
        // otherwise we'd fail out before the user finished typing.

        return race(timeout, devices).then { [self] registeredDevices -> Promise<Void> in
            guard !registeredDevices.contains(where: { $0.id == Current.settingsStore.integrationDeviceID }) else {
                // if the integration is registered already, we will take over that one, so we don't need to look
                return .value(())
            }

            // this can be removed once the mobile_app notify service stops being device name specific
            return promptForDeviceName(
                deviceName: Current.device.deviceName(),
                registeredDevices: registeredDevices,
                sender: sender
            )
        }
    }

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

    private func promptForDeviceName(
        deviceName: String,
        registeredDevices: [RegisteredDevice],
        sender: UIViewController
    ) -> Promise<Void> {
        guard registeredDevices.contains(where: { $0.matches(name: deviceName) }) else {
            // if the device name is not already taken, we can safely use it and don't need to prompt
            return .value(())
        }

        return Promise<Void> { seal in
            let alert = UIAlertController(
                title: L10n.Onboarding.DeviceNameCheck.Error.title(deviceName),
                message: L10n.Onboarding.DeviceNameCheck.Error.prompt,
                preferredStyle: .alert
            )

            alert.addTextField { textField in
                textField.keyboardType = .default
                textField.placeholder = deviceName
                textField.text = deviceName
                textField.enablesReturnKeyAutomatically = true
                textField.autocapitalizationType = .words
            }

            alert.addAction(.init(title: L10n.cancelLabel, style: .cancel, handler: { _ in
                seal.reject(PMKError.cancelled)
            }))

            alert.addAction(.init(
                title: L10n.Onboarding.DeviceNameCheck.Error.renameAction,
                style: .default,
                handler: { [self] _ in
                    let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces)

                    guard let name = name, name.isEmpty == false,
                          !registeredDevices.contains(where: { $0.matches(name: name) }) else {
                        promptForDeviceName(
                            deviceName: deviceName,
                            registeredDevices: registeredDevices,
                            sender: sender
                        ).pipe(to: seal.resolve)
                        return
                    }

                    api.server.info.setSetting(value: name, for: .overrideDeviceName)
                    seal.fulfill(())
                }
            ))

            sender.present(alert, animated: true, completion: nil)
        }
    }
}
