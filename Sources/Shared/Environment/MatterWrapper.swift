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

    #if os(iOS)
    public var threadClientService: ThreadClientProtocol = ThreadClientService()

    public var lastCommissionServerIdentifier: Identifier<Server>? {
        get { Current.settingsStore.prefs.string(forKey: "lastCommissionServerID").flatMap { .init(rawValue: $0) } }
        set { Current.settingsStore.prefs.set(newValue?.rawValue, forKey: "lastCommissionServerID") }
    }

    public lazy var commission: (_ server: Server) -> Promise<String?> = { [self] server in
        #if canImport(MatterSupport)
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
    #endif
}
