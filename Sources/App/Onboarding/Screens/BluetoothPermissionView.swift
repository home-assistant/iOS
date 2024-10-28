import CoreBluetooth
import Foundation
import Shared
import SwiftUI

struct BluetoothPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BluetoothPermissionViewModel()

    var body: some View {
        PermissionRequestView(
            icon: .bluetoothIcon,
            title: L10n.Permission.Screen.Bluetooth.title,
            subtitle: L10n.Permission.Screen.Bluetooth.subtitle,
            reasons: [
                .init(
                    icon: .accessPointIcon,
                    text: L10n.Permission.Screen.Bluetooth.reason1
                ),
            ],
            showSkipButton: true,
            continueAction: {
                // Request BT permission
                viewModel.requestAuthorization()
            },
            dismissAction: nil
        )
        .interactiveDismissDisabled(true)
        .onAppear {
            // Permission will be prompted twice, if ignored, it wont display anymore
            let btScreenDisplayerCount = BluetoothPermissionScreenDisplayedCount()
            btScreenDisplayerCount.value = (btScreenDisplayerCount.value ?? 0) + 1
        }
        .onChange(of: viewModel.shouldDismiss) { newValue in
            if newValue {
                dismiss()
            }
        }
    }
}

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

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            BluetoothPermissionView()
        }
}
