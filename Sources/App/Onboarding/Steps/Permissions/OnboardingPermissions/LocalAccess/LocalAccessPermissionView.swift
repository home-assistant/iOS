import Shared
import SwiftUI
import SFSafeSymbols

struct LocalAccessPermissionView: View {
    @StateObject private var viewModel: LocalAccessPermissionViewModel
    @State private var showLocationSharingScreen = false
    let permission: PermissionType
    let primaryButtonAction: () -> Void
    let secondaryButtonAction: () -> Void

    init(
        onboardingServer: Server,
        permission: PermissionType,
        primaryButtonAction: @escaping () -> Void,
        secondaryButtonAction: @escaping () -> Void
    ) {
        self._viewModel = .init(wrappedValue: LocalAccessPermissionViewModel(onboardingServer: onboardingServer))
        self.permission = permission
        self.primaryButtonAction = primaryButtonAction
        self.secondaryButtonAction = secondaryButtonAction
    }

    var body: some View {
        Group {
            BaseOnboardingTemplateView<Image, AnyView>(
                icon: {
                    Image(.Onboarding.localAccess)
                },
                title: L10n.Onboarding.LocalAccess.title,
                subtitle: L10n.Onboarding.LocalAccess.body,
                bannerText: L10n.Onboarding.LocalAccess.bannerText,
                primaryButtonTitle: L10n.Onboarding.LocalAccess.primaryButton,
                primaryButtonAction: {
                    permission.request { _, _ in
                        primaryButtonAction()
                    }
                },
                secondaryButtonTitle: L10n.Onboarding.LocalAccess.secondaryButton,
                secondaryButtonAction: {
                    secondaryButtonAction()
                }
            )
        }
    }
}
