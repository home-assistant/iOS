import Foundation
import Shared
import PromiseKit

#if targetEnvironment(simulator)
class SimulatorTagManager: iOSTagManager {
    override var isNFCAvailable: Bool {
        true
    }

    override func readNFC() -> Promise<String> {
        return .value(UUID().uuidString.lowercased())
    }

    override func writeNFC(value: String) -> Promise<String> {
        return .value(value)
    }
}
#endif
