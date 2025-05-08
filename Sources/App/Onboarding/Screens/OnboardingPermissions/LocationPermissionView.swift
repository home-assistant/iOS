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
        VStack(spacing: Spaces.two) {
            Image(uiImage: permission.enableIcon.image(
                ofSize: .init(width: 100, height: 100),
                color: nil
            ).withRenderingMode(.alwaysTemplate))
                .foregroundStyle(Color.asset(Asset.Colors.haPrimary))
            Text(verbatim: permission.title)
                .font(.title.bold())
            Text(verbatim: permission.enableDescription)
                .multilineTextAlignment(.center)
                .opacity(0.5)
            bullets
                .padding(.top, Spaces.one)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var bullets: some View {
        VStack(alignment: .leading) {
            ForEach(permission.enableBulletPoints, id: \.id) { bullet in
                makeBulletRow(bullet)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func makeBulletRow(_ bullet: PermissionType.BulletPoint) -> some View {
        HStack(spacing: Spaces.one) {
            Image(uiImage: bullet.icon.image(ofSize: .init(width: 35, height: 35), color: .accent))
                .foregroundStyle(Color.asset(Asset.Colors.haPrimary))
            Text(verbatim: bullet.text)
                .font(.body.bold())
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Spaces.two) {
            Button(action: {
                viewModel.enableLocationSensor()
                viewModel.requestLocationPermission()
            }, label: {
                Text(L10n.continueLabel)
            })
            .buttonStyle(.primaryButton)
            Button(action: {}, label: {
                Text(L10n.Onboarding.Permissions.changeLaterNote)
            })
            .buttonStyle(.linkButton)
        }
    }
}

#Preview {
    LocationPermissionView(permission: .location) {}
}
