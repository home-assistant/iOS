import Shared
import SwiftUI

enum LocalAccessPermissionOptions: String {
    case secure
    case lessSecure
}

struct LocalAccessPermissionView: View {
    @StateObject private var viewModel = LocalAccessPermissionViewModel()

    private let locationOptions = [
        SelectionOption(
            value: LocalAccessPermissionOptions.secure.rawValue,
            title: L10n.Onboarding.LocalAccess.SecureOption.title,
            subtitle: nil,
            isRecommended: true
        ),
        SelectionOption(
            value: LocalAccessPermissionOptions.lessSecure.rawValue,
            title: L10n.Onboarding.LocalAccess.LessSecureOption.title,
            subtitle: nil,
            isRecommended: false
        ),
    ]

    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.lock)
            },
            title: L10n.Onboarding.LocalAccess.title,
            primaryDescription: L10n.Onboarding.LocalAccess.description,
            secondaryDescription: nil,
            content: {
                VStack(spacing: DesignSystem.Spaces.four) {
                    SelectionOptionView(options: locationOptions, selection: $viewModel.selection)
                    HStack(spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: .lock)
                            .foregroundStyle(.haPrimary)
                            .font(DesignSystem.Font.body)

                        Text(L10n.Onboarding.LocalAccess.privacyDisclaimer)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spaces.two)
                }
            },
            primaryActionTitle: L10n.Onboarding.LocalAccess.nextButton,
            primaryAction: {
                if viewModel.selection == LocalAccessPermissionOptions.secure.rawValue {
                    primaryAction()
                } else {
                    // Considered as if the user decided to ignore
                    secondaryAction()
                }
            },
            secondaryActionTitle: nil,
            secondaryAction: {
                secondaryAction()
            }
        )
    }
}

#Preview {
    LocalAccessPermissionView {
        
    } secondaryAction: {

    }

}
