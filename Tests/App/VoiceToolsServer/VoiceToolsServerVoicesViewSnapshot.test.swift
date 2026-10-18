@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

/// Rendered without a navigation container on purpose: the search field only appears inside one,
/// and where the OS draws it differs between the iOS the references are recorded on and the one CI
/// runs, so these pin the rows alone.
struct VoiceToolsServerVoicesViewSnapshotTests {
    private var sampleVoices: [OnDeviceVoice] {
        [
            OnDeviceVoice(
                identifier: "com.apple.voice.compact.en-US.Samantha",
                name: "Samantha",
                language: "en-US",
                quality: .default
            ),
            OnDeviceVoice(
                identifier: "com.apple.voice.enhanced.en-US.Evan",
                name: "Evan",
                language: "en-US",
                quality: .enhanced
            ),
            OnDeviceVoice(
                identifier: "com.apple.voice.premium.pt-BR.Luciana",
                name: "Luciana",
                language: "pt-BR",
                quality: .premium
            ),
        ]
    }

    /// The list is injected so the snapshot does not depend on which voices the machine rendering it
    /// has installed.
    @MainActor @Test func voices() {
        assertLightDarkSnapshots(
            of: VoiceToolsServerVoicesView(voices: sampleVoices),
            drawHierarchyInKeyWindow: true
        )
    }

    /// A search matches either a voice or the language it is grouped under.
    @MainActor @Test func filtered() {
        assertLightDarkSnapshots(
            of: VoiceToolsServerVoicesView(voices: sampleVoices, searchTerm: "Luci"),
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func noVoices() {
        assertLightDarkSnapshots(
            of: VoiceToolsServerVoicesView(voices: []),
            drawHierarchyInKeyWindow: true
        )
    }
}
