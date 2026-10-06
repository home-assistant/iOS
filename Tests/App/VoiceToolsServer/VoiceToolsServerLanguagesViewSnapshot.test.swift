@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

struct VoiceToolsServerLanguagesViewSnapshotTests {
    /// The list is injected so the snapshot does not depend on which dictation languages the machine
    /// rendering it has installed.
    @MainActor @Test func languages() {
        assertLightDarkSnapshots(
            of: NavigationView {
                VoiceToolsServerLanguagesView(locales: [
                    Locale(identifier: "en-US"),
                    Locale(identifier: "en-GB"),
                    Locale(identifier: "pt-BR"),
                    Locale(identifier: "de-DE"),
                ])
            },
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func noLanguages() {
        assertLightDarkSnapshots(
            of: NavigationView {
                VoiceToolsServerLanguagesView(locales: [])
            },
            drawHierarchyInKeyWindow: true
        )
    }
}
