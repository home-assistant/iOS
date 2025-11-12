@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing

struct BaseOnboardingViewTests {
    private static let illustration = { Image(.Onboarding.world) }

    @available(iOS 18.0, *)
    @MainActor
    private func assertOnboardingSnapshot(
        _ view: some View,
        named name: String
    ) {
        assertLightDarkSnapshots(of: view, named: name)
    }

    @MainActor @Test func simple() async throws {
        guard #available(iOS 18.0, *) else { return }

        let view = BaseOnboardingView(
            illustration: Self.illustration,
            title: "Use this device's location for automations",
            primaryDescription: "Location sharing enables powerful automations, such as turning off the heating when you leave home. This option shares the device's location only with your Home Assistant system.",
            secondaryDescription: "This data stays in your home and is never sent to third parties. It also helps strengthen the security of your connection to Home Assistant.",
            primaryActionTitle: "Share my location",
            primaryAction: {},
            secondaryActionTitle: "Do not share my location",
            secondaryAction: {}
        )

        assertOnboardingSnapshot(view, named: "simple")
    }

    @MainActor @Test func withInjectedContent() async throws {
        guard #available(iOS 18.0, *) else { return }

        let view = BaseOnboardingView(
            illustration: Self.illustration,
            title: "Use this device's location for automations",
            primaryDescription: "Location sharing enables powerful automations.",
            secondaryDescription: "This data stays in your home and is never sent to third parties.",
            content: {
                VStack(spacing: DesignSystem.Spaces.one) {
                    Toggle(isOn: .constant(true)) {
                        Text("Also share precise location")
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("You can change this later in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: DesignSystem.List.rowMaxWidth)
            },
            primaryActionTitle: "Share my location",
            primaryAction: {},
            secondaryActionTitle: "Do not share my location",
            secondaryAction: {}
        )

        assertOnboardingSnapshot(view, named: "with-injected-content")
    }

    @MainActor @Test func withoutSecondaryAction() async throws {
        guard #available(iOS 18.0, *) else { return }

        let view = BaseOnboardingView(
            illustration: Self.illustration,
            title: "Welcome to Home Assistant",
            primaryDescription: "Control your smart home with ease and privacy.",
            primaryActionTitle: "Get Started",
            primaryAction: {}
        )

        assertOnboardingSnapshot(view, named: "no-secondary-action")
    }

    @MainActor @Test func withoutSecondaryDescription() async throws {
        guard #available(iOS 18.0, *) else { return }

        let view = BaseOnboardingView(
            illustration: Self.illustration,
            title: "Setup Complete",
            primaryDescription: "Your Home Assistant is ready to use.",
            primaryActionTitle: "Continue",
            primaryAction: {},
            secondaryActionTitle: "Go Back",
            secondaryAction: {}
        )

        assertOnboardingSnapshot(view, named: "no-secondary-description")
    }
}
