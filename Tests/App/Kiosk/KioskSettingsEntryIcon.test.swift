@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

struct KioskSettingsEntryIconTests {
    @MainActor
    @Test func visibleAndHiddenEntry() async throws {
        // The hidden icon draws nothing at all, but still takes up the same space as the visible one:
        // the gap below the first circle is the invisible-but-tappable entry.
        let view = VStack(spacing: DesignSystem.Spaces.two) {
            KioskSettingsEntryIcon(
                backgroundColor: Color(hex: KioskSettingsEntryIcon.defaultBackgroundColorHex),
                iconColor: Color(hex: KioskSettingsEntryIcon.defaultIconColorHex)
            )
            KioskSettingsEntryIcon(
                backgroundColor: Color(hex: KioskSettingsEntryIcon.defaultBackgroundColorHex),
                iconColor: Color(hex: KioskSettingsEntryIcon.defaultIconColorHex),
                isHidden: true
            )
        }
        .padding(DesignSystem.Spaces.two)

        assertLightDarkSnapshots(of: view)
    }
}
