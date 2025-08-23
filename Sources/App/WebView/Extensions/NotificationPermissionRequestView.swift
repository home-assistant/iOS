import Shared
import SwiftUI

struct NotificationPermissionRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bottomSheetState: AppleLikeBottomSheetViewState?

    var body: some View {
        AppleLikeBottomSheet(
            title: L10n.Permission.Notification.title, content: {
                VStack(spacing: DesignSystem.Spaces.three) {
                    ScrollView {
                        Text(L10n.Permission.Notification.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, DesignSystem.Spaces.one)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 200)
                    VStack(spacing: DesignSystem.Spaces.one) {
                        Button {
                            triggerNativePopup()
                        } label: {
                            Text(L10n.Permission.Notification.primaryButton)
                        }
                        .buttonStyle(.primaryButton)
                        Button {
                            triggerNativePopup()
                        } label: {
                            Text(L10n.Permission.Notification.secondaryButton)
                        }
                        .buttonStyle(.secondaryButton)
                    }
                }
            },
            contentInsets: .init(
                top: .zero,
                leading: DesignSystem.Spaces.two,
                bottom: DesignSystem.Spaces.three,
                trailing: DesignSystem.Spaces.two
            ),
            bottomSheetMinHeight: 310,
            state: $bottomSheetState
        )
    }

    private func triggerNativePopup() {
        dismiss()
        UNUserNotificationCenter.current().requestAuthorization(options: .defaultOptions) { _, error in
            if let error {
                Current.Log.error("Error when requesting notifications permissions: \(error)")
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

#Preview {
    NotificationPermissionRequestView()
}
