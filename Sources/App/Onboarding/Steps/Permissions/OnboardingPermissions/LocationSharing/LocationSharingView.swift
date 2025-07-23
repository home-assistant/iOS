import Shared
import SwiftUI
import SFSafeSymbols

struct LocationSharingView: View {
    @StateObject private var viewModel = LocationSharingViewModel()
    let permission: PermissionType
    let primaryButtonAction: () -> Void
    let secondaryButtonAction: () -> Void

    var body: some View {
        Group {
            BaseOnboardingTemplateView<Image, AnyView>(
                icon: {
                    Image(.Onboarding.locationAccess)
                },
                title: L10n.Onboarding.LocalAccess.title,
                subtitle: L10n.Onboarding.LocalAccess.body,
                bannerText: L10n.Onboarding.LocalAccess.bannerText,
                primaryButtonTitle: L10n.Onboarding.LocalAccess.primaryButton,
                primaryButtonAction: {
                    permission.request { granted, status in
                        if granted {
                            viewModel.enableLocationSensor()
                        } else {
                            viewModel.disableLocationSensor()
                        }
                        primaryButtonAction()
                    }
                },
                secondaryButtonTitle: L10n.Onboarding.LocalAccess.secondaryButton,
                secondaryButtonAction: {
                    viewModel.disableLocationSensor()
                    secondaryButtonAction()
                }
            )
        }
    }
}
