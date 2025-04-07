import CoreBluetooth
import Foundation
import Shared

final class BluetoothPermissionViewModel: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var shouldDismiss: Bool = false

    private var cbManager: CBCentralManager?

    func requestAuthorization() {
        cbManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [weak self] in
            switch central.state {
            case .poweredOn:
                Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                    .done { controller in
                        controller.webViewExternalMessageHandler.scanImprov()
                        self?.shouldDismiss = true
                    }
            default:
                self?.shouldDismiss = true
            }
        }
    }
}
