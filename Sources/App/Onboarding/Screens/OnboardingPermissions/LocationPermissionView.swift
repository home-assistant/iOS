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
            L10n.Onboarding.Permission.Location.Deny.Alert.title,
            isPresented: $viewModel.showDenyAlert,
            actions: {
                Button(L10n.continueLabel, role: .destructive) {
                    viewModel.requestLocationPermission()
                }
            },
            message: {
                Text(verbatim: L10n.Onboarding.Permission.Location.Deny.Alert.message)
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
        VStack(spacing: Spaces.two) {
            Image(uiImage: permission.enableIcon.image(
                ofSize: .init(width: 100, height: 100),
                color: nil
            ).withRenderingMode(.alwaysTemplate))
                .foregroundStyle(Color.asset(Asset.Colors.haPrimary))
            Text(verbatim: permission.title)
                .font(.title.bold())
            Text(verbatim: L10n.Onboarding.Permission.Location.description)
                .multilineTextAlignment(.center)
                .opacity(0.5)
            PrivacyNoteView(content: L10n.Onboarding.Permission.Location.privacyNote)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var actionButtons: some View {
        VStack(spacing: Spaces.one) {
            Button {
                viewModel.enableLocationSensor()
                viewModel.requestLocationPermission()
            } label: {
                Text(L10n.Onboarding.Permission.Location.Buttons.allowAndShare)
            }
            .buttonStyle(.primaryButton)
            Button {
                viewModel.disableLocationSensor()
                viewModel.requestLocationPermission()
            } label: {
                Text(L10n.Onboarding.Permission.Location.Buttons.allowForApp)
            }
            .buttonStyle(.primaryButton)
            Button {
                viewModel.disableLocationSensor()
                viewModel.showDenyAlert = true
            } label: {
                Text(L10n.Onboarding.Permission.Location.Buttons.deny)
            }
            .buttonStyle(.secondaryNegativeButton)
        }
    }
}

#Preview {
    LocationPermissionView(permission: .location) {}
}
