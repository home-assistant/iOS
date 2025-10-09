import Shared
import SwiftUI

enum LocalAccessPermissionOptions: String {
    case secure
    case lessSecure
}

struct LocalAccessPermissionView: View {
    @StateObject private var viewModel: LocalAccessPermissionViewModel
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

    init(server: Server) {
        _viewModel = .init(wrappedValue: LocalAccessPermissionViewModel(server: server))
    }

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
                    NavigationLink("", isActive: $viewModel.showHomeNetworkConfiguration) {
                        HomeNetworkInputView(onNext: { networkSSID in
                            if let networkSSID {
                                viewModel.saveNetworkSSID(networkSSID)
                            }
                            completeOnboarding()
                        }, onSkip: {
                            completeOnboarding()
                        })
                    }
                }
            },
            primaryActionTitle: L10n.Onboarding.LocalAccess.nextButton,
            primaryAction: {
                viewModel.primaryAction()
            },
            secondaryActionTitle: nil,
            secondaryAction: {
                viewModel.secondaryAction()
                completeOnboarding()
            }
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private func completeOnboarding() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Current.onboardingObservation.complete()
        }
    }
}

#Preview {
    LocalAccessPermissionView(server: ServerFixture.standard)
}
