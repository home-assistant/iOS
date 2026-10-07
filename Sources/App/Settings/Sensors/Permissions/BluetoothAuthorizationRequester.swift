import CoreBluetooth
import Foundation

/// Instantiating a `CBCentralManager` is what surfaces the Bluetooth prompt; the delegate callback
/// reports the outcome so a caller can refresh what it shows.
final class BluetoothAuthorizationRequester: NSObject, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private var onChange: (() -> Void)?

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init()
    }

    func request() {
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    /// The delegate reports every later state change too, while the caller is waiting on exactly
    /// one answer, so the callback and the manager are let go before answering: a Bluetooth state
    /// change afterwards must not report a second time.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard let onChange else { return }
        self.onChange = nil
        manager = nil
        onChange()
    }
}
