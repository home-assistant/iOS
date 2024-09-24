#if canImport(MatterSupport)
import MatterSupport
#endif
import PromiseKit

public class MatterWrapper {
    public var isAvailable: Bool = {
        #if canImport(MatterSupport)
        if #available(iOS 16.1, *) {
            return true
        } else {
            return false
        }
        #else
        return false
        #endif
    }()

    public var threadCredentialsSharingEnabled: Bool {
        // For now mac is not returning thread credentials for some reason
        #if canImport(ThreadNetwork) && !targetEnvironment(macCatalyst)
        if #available(iOS 16.4, *) {
            return true
        } else {
            return false
        }
        #else
        return false
        #endif
    }

    public var threadCredentialsStoreInKeychainEnabled: Bool {
        #if canImport(ThreadNetwork) && !targetEnvironment(macCatalyst)
        if #available(iOS 16.4, *) {
            return true
        } else {
            return false
        }
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

    public lazy var commission: (_ server: Server) -> Promise<Void> = { [self] server in
        #if canImport(MatterSupport)
        guard #available(iOS 16.4, *) else {
            return .value(())
        }

        lastCommissionServerIdentifier = server.identifier

        let request = MatterAddDeviceRequest(
            topology: .init(ecosystemName: "Home Assistant", homes: []),
            shouldScanNetworks: true
        )

        return Promise<Void> { seal in
            Task {
                do {
                    try await request.perform()
                    Current.Log.info("Matter pairing finished (native flow manually closed or pairing succeeded)")
                    seal.fulfill(())
                } catch {
                    Current.Log.error("Matter pairing failed: \(error)")
                    seal.reject(error)
                }
            }
        }
        #else
        return .value(())
        #endif
    }
    #endif
}
