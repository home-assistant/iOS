import Shared
import SwiftUI

/// Asks what a newly added server receives from this device.
///
/// Only shown while onboarding a server into an app that already has another one: the first server
/// settles these choices through the location permission screen, but every server after it would
/// otherwise start on the defaults without anyone being asked. Nothing is selected to begin with
/// and the flow cannot be continued until both questions are answered.
struct OnboardingPrivacyView: View {
    @StateObject private var viewModel: OnboardingPrivacyViewModel

    init(
        locationPrivacy: ServerLocationPrivacy? = nil,
        sensorPrivacy: ServerSensorPrivacy? = nil,
        action: @escaping (ServerLocationPrivacy, ServerSensorPrivacy) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: OnboardingPrivacyViewModel(
            locationPrivacy: locationPrivacy,
            sensorPrivacy: sensorPrivacy,
            action: action
        ))
    }

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.lock)
            },
            title: L10n.Onboarding.Privacy.title,
            primaryDescription: L10n.Onboarding.Privacy.description,
            secondaryDescription: nil,
            content: {
                VStack(spacing: DesignSystem.Spaces.four) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                        Text(L10n.Settings.ConnectionSection.LocationSendType.title)
                            .font(DesignSystem.Font.footnote.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignSystem.Spaces.two)

                        SelectionOptionView(
                            options: viewModel.locationOptions,
                            selection: viewModel.locationSelection
                        )
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                        Text(L10n.Settings.ConnectionSection.SensorSendType.title)
                            .font(DesignSystem.Font.footnote.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignSystem.Spaces.two)

                        SelectionOptionView(
                            options: viewModel.sensorOptions,
                            selection: viewModel.sensorSelection
                        )
                    }

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
            primaryActionTitle: L10n.continueLabel,
            primaryAction: {
                viewModel.submit()
            },
            primaryActionIdentifier: AccessibilityIdentifier.onboardingPrivacyNext.rawValue
        )
        .disableOnboardingPrimaryAction(!viewModel.canSubmit)
    }
}

#Preview {
    OnboardingPrivacyView { _, _ in
    }
}

#Preview("Nothing shared") {
    OnboardingPrivacyView(locationPrivacy: .never, sensorPrivacy: ServerSensorPrivacy.none) { _, _ in
    }
}
