import Shared
import SwiftUI

struct NotificationPermissionRequestView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            // The sheet is fixed to the medium detent, so the text scrolls rather than pushing the
            // buttons out of reach at large type sizes or in a longer language.
            ScrollView {
                VStack(spacing: DesignSystem.Spaces.three) {
                    Text(L10n.Permission.Notification.title)
                        .font(DesignSystem.Font.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(L10n.Permission.Notification.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            VStack(spacing: DesignSystem.Spaces.one) {
                Button {
                    triggerNativePopup()
                } label: {
                    Text(L10n.Permission.Notification.primaryButton)
                }
                .buttonStyle(.primaryButton)
                .accessibilityIdentifier(AccessibilityIdentifier.notificationPermissionRequestPrimary.rawValue)
                Button {
                    triggerNativePopup()
                } label: {
                    Text(L10n.Permission.Notification.secondaryButton)
                }
                .buttonStyle(.secondaryButton)
                .accessibilityIdentifier(
                    AccessibilityIdentifier.notificationPermissionRequestSecondary.rawValue
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.three)
        .padding(.top, DesignSystem.Spaces.four)
        .padding(.bottom, DesignSystem.Spaces.one)
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

@available(iOS 17.0, *)
#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NotificationPermissionRequestView()
                .presentationDetents([.medium])
        }
}
