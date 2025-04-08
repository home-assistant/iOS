import CoreBluetooth
import Foundation
import Shared
import SwiftUI

struct BluetoothPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BluetoothPermissionViewModel()

    var body: some View {
        PermissionRequestView(
            icon: .radarIcon,
            title: L10n.Permission.Screen.Bluetooth.title,
            subtitle: L10n.Permission.Screen.Bluetooth.subtitle,
            reasons: [],
            showSkipButton: false,
            showCloseButton: true,
            continueAction: {
                // Request BT permission
                viewModel.requestAuthorization()
            },
            dismissAction: nil
        )
        .interactiveDismissDisabled(true)
        .onChange(of: viewModel.shouldDismiss) { newValue in
            if newValue {
                dismiss()
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
