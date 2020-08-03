import Foundation
import Shared
import PromiseKit

#if targetEnvironment(simulator)
class SimulatorNFCManager: iOSNFCManager {
    override var isAvailable: Bool {
        true
    }

    override func read() -> Promise<String> {
        return .value(UUID().uuidString.lowercased())
    }

    override func write(value: String) -> Promise<String> {
        return .value(value)
    }
}
#endif
