import Shared
import SwiftUI

struct LocationPermissionView: View {
    @StateObject private var viewModel = LocationPermissionViewModel()
    let permission: PermissionType
    let completeAction: () -> Void

    var body: some View {
        BasePermissionView(
            illustration: {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.secondary)
                    .overlay(
                        Text("Illustration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
                    .padding(.top, DesignSystem.Spaces.four)
            },
            title: "Use this device's location for automations",
            primaryDescription: "Location sharing enables powerful automations, such as turning off the heating when you leave home. This option shares the device’s location only with your Home Assistant system.",
            secondaryDescription: "This data stays in your home and is never sent to third parties. It also helps strengthen the security of your connection to Home Assistant.",
            primaryActionTitle: "Share my location",
            primaryAction: {
                viewModel.requestLocationPermission()
            },
            secondaryActionTitle: "Do not share my location",
            secondaryAction: {
                // TODO: Move to the next screen without requesting permission
            }
        )
        .navigationBarTitleDisplayMode(.inline)
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
