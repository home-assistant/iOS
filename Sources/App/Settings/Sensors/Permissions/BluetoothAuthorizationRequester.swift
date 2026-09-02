import CoreBluetooth
import Foundation

/// Instantiating a `CBCentralManager` is what surfaces the Bluetooth prompt; the delegate callback
/// reports the outcome so a caller can refresh what it shows.
final class BluetoothAuthorizationRequester: NSObject, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init()
    }

    func request() {
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onChange()
    }
}
