#if canImport(MatterSupport)
import MatterSupport
#endif
import PromiseKit

public struct MatterWrapper {
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

    public var comission: () -> Promise<Void> = {
        #if canImport(MatterSupport)
        guard #available(iOS 16.1, *) else {
            return .value(())
        }

        return Promise<Void> { seal in
            Task {
                do {
                    try await MatterAddDeviceRequest(topology: .init(ecosystemName: "Home Assistant", homes: []))
                        .perform()
                    Current.Log.info("matter pairing successful")
                    seal.fulfill(())
                } catch {
                    Current.Log.error("matter pairing failed: \(error)")
                    seal.reject(error)
                }
            }
        }
        #else
        return .value(())
        #endif
    }
}
