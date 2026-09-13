import Foundation
import PromiseKit
import Shared

#if targetEnvironment(simulator)
final class SimulatorTagManager: iOSTagManager {
    override var isNFCAvailable: Bool {
        true
    }

    override func readNFC() -> Promise<String> {
        .value(UUID().uuidString.lowercased())
    }

    override func writeNFC(value: String) -> Promise<String> {
        .value(value)
    }

    override func writeNFC(deeplink: URL, alertMessage: String) -> Promise<Void> {
        Current.Log.info("Simulator pretending to write \(deeplink.absoluteString) to an NFC tag")
        return .value(())
    }
}
#endif
