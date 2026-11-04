import HAKit
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The onboarding connection error screen: the description, error code and server response it
/// lists for each kind of failure, and the troubleshooting anchor it links to.
@MainActor
struct OnboardingErrorViewTests {
    private func render(_ error: Error) {
        let controller = UIHostingController(rootView: OnboardingErrorView(error: error))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1200))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    @Test func rendersAPlainError() {
        render(HAError.internal(debugDescription: "Something broke"))
        render(URLError(.timedOut))
    }

    @Test func rendersAnOnboardingErrorWithItsCodeAndResponse() {
        render(OnboardingAuthError(
            kind: .other(URLError(.cannotFindHost)),
            data: Data("<html>Bad gateway</html>".utf8)
        ))
        render(OnboardingAuthError(kind: .invalidURL))
        render(OnboardingAuthError(kind: .basicAuth))
        render(OnboardingAuthError(kind: .authenticationUnsupported("digest")))
        render(OnboardingAuthError(kind: .sslUntrusted([URLError(.serverCertificateUntrusted)])))
        render(OnboardingAuthError(kind: .clientCertificateRequired))
    }
}
