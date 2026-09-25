#if canImport(HomeKit) && canImport(Matter) && os(iOS) && !targetEnvironment(macCatalyst)
import HomeKit
import Matter
#endif
#if canImport(MatterSupport)
import MatterSupport
#endif
import PromiseKit

public class MatterWrapper {
    public var isAvailable: Bool = {
        #if canImport(MatterSupport) && !targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }()

    public var threadCredentialsSharingEnabled: Bool {
        // For now mac is not returning thread credentials for some reason
        #if canImport(ThreadNetwork) && !targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    public var threadCredentialsStoreInKeychainEnabled: Bool {
        #if canImport(ThreadNetwork) && !targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    /// Whether a device already commissioned to Home Assistant can be shared to the platform's home app.
    public lazy var canShareDevice: Bool = {
        #if canImport(HomeKit) && canImport(Matter) && os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 27, *) {
            return HMAccessorySetupManager.isSupported
        }
        return true
        #else
        return false
        #endif
    }()

    /// Where a shared device lands, so the frontend can label the action.
    public let shareTarget = "apple_home"

    #if os(iOS)
    public var threadClientService: ThreadClientProtocol = ThreadClientService()

    public var lastCommissionServerIdentifier: Identifier<Server>? {
        get { Current.settingsStore.prefs.string(forKey: "lastCommissionServerID").flatMap { .init(rawValue: $0) } }
        set { Current.settingsStore.prefs.set(newValue?.rawValue, forKey: "lastCommissionServerID") }
    }

    public lazy var commission: (_ server: Server) -> Promise<String?> = { [self] server in
        #if canImport(MatterSupport) && !targetEnvironment(macCatalyst)
        lastCommissionServerIdentifier = server.identifier
        Current.settingsStore.matterLastCommissionedDeviceName = nil

        let request = MatterAddDeviceRequest(
            topology: .init(ecosystemName: "Home Assistant", homes: []),
            shouldScanNetworks: true
        )

        return Promise<String?> { seal in
            Task {
                do {
                    try await request.perform()
                    let deviceName = Current.settingsStore.matterLastCommissionedDeviceName
                    // Reset device name after reading it, so that if the user tries to pair another device without
                    // going through the flow again, we won't have a stale name hanging around
                    Current.settingsStore.matterLastCommissionedDeviceName = nil
                    Current.Log.info("Matter pairing finished (native flow manually closed or pairing succeeded)")
                    seal.fulfill(deviceName)
                } catch {
                    Current.Log.error("Matter pairing failed: \(error)")
                    seal.reject(error)
                }
            }
        }
        #else
        return .value(nil)
        #endif
    }

    /// Adds a device that is already commissioned to Home Assistant to Apple Home (Matter multi-admin),
    /// through the commissioning window Home Assistant opened for it.
    public var shareDevice: (_ request: MatterShareRequest) async throws -> Void = { request in
        #if canImport(HomeKit) && canImport(Matter) && os(iOS) && !targetEnvironment(macCatalyst)
        guard let payload = MatterWrapper.setupPayload(for: request) else {
            throw MatterShareError.invalidRequest
        }
        let setupRequest = HMAccessorySetupRequest()
        setupRequest.matterPayload = payload
        setupRequest.suggestedAccessoryName = request.deviceName
        _ = try await HMAccessorySetupManager().performAccessorySetup(using: setupRequest)
        #else
        throw MatterShareError.unsupported
        #endif
    }

    #if canImport(HomeKit) && canImport(Matter) && os(iOS) && !targetEnvironment(macCatalyst)
    /// The setup payload for the home app, built from the window's values where the server reported them and
    /// otherwise by Apple's parser from the setup code. Nil if the setup code does not parse.
    static func setupPayload(for request: MatterShareRequest) -> MTRSetupPayload? {
        switch request.window {
        case let .values(passcode, discriminator, vendorID, productID):
            let payload = MTRSetupPayload(
                setupPasscode: NSNumber(value: passcode),
                discriminator: NSNumber(value: discriminator)
            )
            payload.hasShortDiscriminator = false
            // Home Assistant opens the window on the device's operational network.
            payload.discoveryCapabilities = .onNetwork
            if let vendorID {
                payload.vendorID = NSNumber(value: vendorID)
            }
            if let productID {
                payload.productID = NSNumber(value: productID)
            }
            return payload
        case let .setupCode(setupCode):
            if #available(iOS 17.6, *) {
                return MTRSetupPayload(payload: setupCode)
            }
            return try? MTRSetupPayload(onboardingPayload: setupCode)
        }
    }
    #endif

    /// Maps a share failure to the external bus error code.
    public static func shareErrorCode(for error: Error) -> String {
        #if canImport(HomeKit) && canImport(Matter) && os(iOS) && !targetEnvironment(macCatalyst)
        if let error = error as? HMError, error.code == .operationCancelled {
            return "cancelled"
        }
        #endif
        return "failed"
    }
    #endif
}
