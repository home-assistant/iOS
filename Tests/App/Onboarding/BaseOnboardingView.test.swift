@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing
import Shared

struct BaseOnboardingViewTests {
    @MainActor @Test func testSimpleSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                BaseOnboardingView(
                    illustration: {
                        Image(.Onboarding.world)
                    },
                    title: "Use this device's location for automations",
                    primaryDescription: "Location sharing enables powerful automations, such as turning off the heating when you leave home. This option shares the device's location only with your Home Assistant system.",
                    secondaryDescription: "This data stays in your home and is never sent to third parties. It also helps strengthen the security of your connection to Home Assistant.",
                    primaryActionTitle: "Share my location",
                    primaryAction: {},
                    secondaryActionTitle: "Do not share my location",
                    secondaryAction: {}
                )
                .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view, named: "simple")
    }
    
    @MainActor @Test func testWithInjectedContentSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                BaseOnboardingView(
                    illustration: {
                        Image(.Onboarding.world)
                    },
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
                .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view, named: "with-injected-content")
    }
    
    @MainActor @Test func testWithoutSecondaryActionSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                BaseOnboardingView(
                    illustration: {
                        Image(.Onboarding.world)
                    },
                    title: "Welcome to Home Assistant",
                    primaryDescription: "Control your smart home with ease and privacy.",
                    primaryActionTitle: "Get Started",
                    primaryAction: {}
                )
                .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view, named: "no-secondary-action")
    }
    
    @MainActor @Test func testWithoutSecondaryDescriptionSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                BaseOnboardingView(
                    illustration: {
                        Image(.Onboarding.world)
                    },
                    title: "Setup Complete",
                    primaryDescription: "Your Home Assistant is ready to use.",
                    primaryActionTitle: "Continue",
                    primaryAction: {},
                    secondaryActionTitle: "Go Back",
                    secondaryAction: {}
                )
                .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view, named: "no-secondary-description")
    }
}
