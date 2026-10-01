import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays out the onboarding screens so their bodies are evaluated, including the navigation bar they hide
/// or colour through the platform's own placement.
@MainActor
@Suite(.serialized)
struct OnboardingScreensRenderTests {
    @Test func navigationViewForEveryStyle() {
        for style in [OnboardingStyle.initial, .required, .secondary] {
            renderInWindow(OnboardingNavigationView(onboardingStyle: style))
        }
    }

    @Test func serversList() {
        renderInWindow(NavigationView {
            OnboardingServersListView(onboardingStyle: .secondary, presenter: OnboardingAuthPresenter())
        })
    }

    @Test func authLogin() throws {
        let details = try OnboardingAuthDetails(baseURL: URL(string: "http://homeassistant.local:8123")!)
        let viewModel = OnboardingAuthLoginViewModel(authDetails: details)
        renderInWindow(NavigationView { OnboardingAuthLoginView(viewModel: viewModel) })
    }
}
