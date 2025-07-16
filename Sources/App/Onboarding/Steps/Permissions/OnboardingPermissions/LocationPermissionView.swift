import Shared
import SwiftUI

struct LocationPermissionView: View {
    @StateObject private var viewModel = LocationPermissionViewModel()
    let permission: PermissionType
    let completeAction: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            Text("Location Permission")
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding()
        .navigationBarBackButtonHidden(false)
        .alert(
            L10n.Onboarding.Permission.Location.Deny.Alert.header,
            isPresented: $viewModel.showDenyAlert,
            actions: {
                Button(L10n.continueLabel, role: .destructive) {
                    viewModel.requestLocationPermission()
                }
            },
            message: {
                Text(verbatim: L10n.Onboarding.Permission.Location.Deny.Alert.body)
            }
        )
        .onChange(of: viewModel.shouldComplete) { newValue in
            if newValue {
                completeAction()
            }
        }
    }
}

#Preview {
    LocationPermissionView(permission: .location) {}
}
