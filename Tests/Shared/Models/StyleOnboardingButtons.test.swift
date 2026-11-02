import Foundation
@testable import Shared
import Testing
import UIKit

/// The onboarding `Style` closures applied to plain UIKit controls.
@MainActor
struct StyleOnboardingButtonsTests {
    @Test func titleLabelIsAHeader() {
        let label = UILabel()
        Style().onboardingTitle(label)
        #expect(label.textAlignment == .center)
        #expect(label.numberOfLines == 0)
        #expect(label.accessibilityTraits.contains(.header))
    }

    @Test func buttonsGetTheirStylesAndTrackTheReadableWidth() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        for apply in [Style().onboardingButtonPrimary, Style().onboardingButtonSecondary] {
            let button = UIButton(type: .custom)
            apply(button)
            #expect(button.layer.cornerRadius == 12)
            #expect(button.configuration != nil)
            #expect(button.backgroundImage(for: .normal) != nil)
            #expect(button.backgroundImage(for: .highlighted) != nil)

            let plain = UIButton()
            apply(plain)
            container.addSubview(plain)
            plain.traitCollectionDidChange(nil)
            container.layoutIfNeeded()
            plain.removeFromSuperview()
        }
        let primary = UIButton()
        Style().onboardingButtonPrimary(primary)
        #expect(primary.role == .primary)
    }
}
