import Foundation
import PromiseKit
import Shared

#if targetEnvironment(simulator)
class SimulatorTagManager: iOSTagManager {
    override var isNFCAvailable: Bool {
        true
    }

    override func readNFC() -> Promise<String> {
        .value(UUID().uuidString.lowercased())
    }

    override func writeNFC(value: String) -> Promise<String> {
        .value(value)
    }
}
#endif
