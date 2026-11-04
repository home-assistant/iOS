@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Renders every variant of every component in the design system's library, in light and dark.
///
/// One image per component covering all of its variants, rather than one per variant: the recorded
/// picture is then exactly what `ComponentsLibraryView` shows for that component, and a capability
/// added to `DesignSystemComponent.variants` without a matching visual change fails review rather
/// than passing silently.
struct ComponentsGallerySnapshotTests {
    /// Wide enough for the buttons, which cap at `DesignSystem.Button.maxWidth`, without letting
    /// the wrapping variants reflow every time a phone size changes.
    private static let width: CGFloat = 350

    private static let timeZone = TimeZone(identifier: "UTC") ?? .gmt

    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    /// Components this test cannot capture, covered by a test of their own instead.
    ///
    /// `AssistVoiceOrbView` is drawn from blurs that the render server composites, so the layer-based
    /// capture used here comes back with only its glyph on a transparent background. Its light
    /// appearance also shifts between OS versions by more than the comparison tolerance allows.
    /// `AssistVoiceOrbViewSnapshotTests` pins it properly — dark only, drawn through a key window.
    private static let notCapturable: Set<DesignSystemComponent> = [.assistVoiceOrb]

    @MainActor
    @Test(arguments: DesignSystemComponent.allCases)
    func componentVariants(component: DesignSystemComponent) {
        guard !Self.notCapturable.contains(component) else {
            return
        }
        assertLightDarkSnapshots(
            of: ComponentVariantsView(component: component)
                .padding()
                .frame(width: Self.width)
                .background(Color(uiColor: .systemBackground))
                // Components that format numbers read the environment's locale, and anything
                // plotting dates — the charts' axis labels — reads its time zone. Pinning both
                // keeps the recorded images independent of how the recording machine is set up:
                // otherwise "12.4 %" and "12,4 %", or "2 AM" and "midnight", disagree between
                // developers and CI.
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.timeZone, Self.timeZone)
                .environment(\.calendar, Self.calendar),
            layout: .sizeThatFits,
            named: component.rawValue
        )
    }
}
