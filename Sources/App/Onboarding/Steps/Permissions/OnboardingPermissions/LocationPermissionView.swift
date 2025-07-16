import Shared
import SwiftUI

struct LocationPermissionView: View {
    @StateObject private var viewModel = LocationPermissionViewModel()
    let permission: PermissionType
    let completeAction: () -> Void

    var body: some View {
        VStack(spacing: Spaces.three) {
            header
            Spacer()
            actionButtons
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding()
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

    @ViewBuilder
    private var header: some View {
        VStack(spacing: Spaces.two) {}
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var actionButtons: some View {
        VStack(spacing: Spaces.two) {
//            Button(action: {
//                viewModel.enableLocationSensor()
//                viewModel.requestLocationPermission()
//            }, label: {
//                Text(L10n.continueLabel)
//            })
//            .buttonStyle(.primaryButton)
//            Button(action: {}, label: {
//                Text(L10n.Onboarding.Permissions.changeLaterNote)
//            })
//            .buttonStyle(.linkButton)
        }
    }
}

#Preview {
    LocationPermissionView(permission: .location) {}
}
