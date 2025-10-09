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
            title: "Most secure: Allow this app to know when you're home",
            subtitle: nil,
            isRecommended: true
        ),
        SelectionOption(
            value: LocalAccessPermissionOptions.lessSecure.rawValue,
            title: "Less secure: Do not allow this app to know when you're home",
            subtitle: nil,
            isRecommended: false
        )
    ]

    init(server: Server) {
        _viewModel = .init(wrappedValue: LocalAccessPermissionViewModel(server: server))
    }

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.lock)
            },
            title: "Let us help secure your remote connection",
            primaryDescription: "If this app knows when you’re away from home, it can choose a more secure way to connect to your Home Assistant system. This requires location services to be enabled.",
            secondaryDescription: nil,
            content: {
                VStack(spacing: DesignSystem.Spaces.four) {
                    SelectionOptionView(options: locationOptions, selection: $viewModel.selection)

                    HStack(spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: .lock)
                            .foregroundStyle(.haPrimary)
                            .font(DesignSystem.Font.body)

                        Text("This data will never be shared with the Home Assistant project or third parties.")
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
            primaryActionTitle: "Next",
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
