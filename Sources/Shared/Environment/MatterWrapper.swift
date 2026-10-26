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

    /// Ignores signing: without the entitlements it is still true and the call fails.
    /// Lazy, so the extensions never query HomeKit.
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

    public var shareDevice: @MainActor (_ request: MatterShareRequest) async throws -> Void = { request in
        #if canImport(HomeKit) && canImport(Matter) && os(iOS) && !targetEnvironment(macCatalyst)
        guard let setupRequest = MatterWrapper.accessorySetupRequest(for: request) else {
            throw MatterShareError.invalidRequest
        }
        // Throws unless setup finished; the returned accessories mean nothing to Home Assistant.
        _ = try await HMAccessorySetupManager().performAccessorySetup(using: setupRequest)
        #else
        throw MatterShareError.unsupported
        #endif
    }

    #if canImport(HomeKit) && canImport(Matter) && os(iOS) && !targetEnvironment(macCatalyst)
    static func accessorySetupRequest(for request: MatterShareRequest) -> HMAccessorySetupRequest? {
        guard let payload = setupPayload(for: request) else {
            return nil
        }
        let setupRequest = HMAccessorySetupRequest()
        setupRequest.matterPayload = payload
        setupRequest.suggestedAccessoryName = request.deviceName
        return setupRequest
    }

    static func setupPayload(for request: MatterShareRequest) -> MTRSetupPayload? {
        switch request.window {
        case let .values(passcode, discriminator, vendorID, productID):
            let payload = MTRSetupPayload(
                setupPasscode: NSNumber(value: passcode),
                discriminator: NSNumber(value: discriminator)
            )
            payload.hasShortDiscriminator = false
            // The values carry no discovery capability; Home Assistant opens windows on the operational network.
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

    /// No system text in the message: it is localized, and the frontend reads only the code.
    public static func shareError(for error: Error) -> WebSocketMessage.ResultError {
        #if canImport(HomeKit) && canImport(Matter) && os(iOS) && !targetEnvironment(macCatalyst)
        if let error = error as? HMError, error.code == .operationCancelled {
            return .canceled("the user dismissed the setup sheet")
        }
        #endif
        return .failed("sharing the device failed: \(Self.diagnostic(for: error))")
    }

    private static func diagnostic(for error: Error) -> String {
        if let error = error as? MatterShareError {
            return error.description
        }
        let error = error as NSError
        return "\(error.domain) \(error.code)"
    }
    #endif
}
