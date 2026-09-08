import Shared
import SwiftUI

/// The previous app's announcement: Home Assistant has a new app, here is what moving to it means,
/// and a button that starts the transfer, or first sends the user to the App Store when the new app
/// is not on the device yet.
struct AppMigrationAnnouncementView: View {
    @ObservedObject private var coordinator = AppMigrationCoordinator.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showsGetNewApp = false
    @State private var didRecordView = false
    let onViewed: () -> Void

    var body: some View {
        NavigationStack {
            BaseOnboardingView(
                illustration: {
                    MaterialDesignIconsImage(icon: .cellphoneArrowDownIcon, size: 96)
                        .foregroundStyle(.haPrimary)
                        .padding(.top, DesignSystem.Spaces.two)
                },
                title: L10n.AppMigration.Announcement.title,
                primaryDescription: L10n.AppMigration.Announcement.body,
                content: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                        HASectionPill(L10n.AppMigration.Announcement.Section.whatChanges)
                        CardView(cornerRadius: DesignSystem.CornerRadius.two) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                                ForEach(AppMigrationAnnouncementItem.allCases) { item in
                                    AppMigrationItemRow(
                                        icon: item.icon,
                                        tint: .haPrimary,
                                        title: item.title,
                                        caption: item.explanation
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, DesignSystem.Spaces.two)
                },
                primaryActionTitle: L10n.AppMigration.Announcement.transferButton,
                primaryAction: {
                    AppMigrationHaptics.tap()
                    if coordinator.beginTransferFromThisApp() {
                        dismiss()
                    } else {
                        showsGetNewApp = true
                    }
                },
                primaryActionIdentifier: AccessibilityIdentifier.migrationAnnouncementTransfer.rawValue,
                secondaryActionTitle: L10n.AppMigration.Announcement.laterButton,
                secondaryAction: {
                    AppMigrationHaptics.tap()
                    dismiss()
                },
                secondaryActionIdentifier: AccessibilityIdentifier.migrationAnnouncementLater.rawValue
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $showsGetNewApp) {
                AppMigrationGetNewAppView(transferStartedAction: { dismiss() })
            }
        }
        .onAppear {
            guard !didRecordView else { return }
            didRecordView = true
            onViewed()
        }
    }
}

#Preview {
    AppMigrationAnnouncementView(onViewed: {})
}
