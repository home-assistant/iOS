@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

struct VoiceToolsServerSettingsViewSnapshotTests {
    /// The controller is left out of every case: these must render the same wherever they run,
    /// without binding a port on the machine running them.
    @MainActor @Test func off() {
        assertLightDarkSnapshots(
            of: NavigationView {
                VoiceToolsServerSettingsView(viewModel: VoiceToolsServerSettingsViewModel(
                    configuration: .init(),
                    controller: nil
                ))
            },
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func running() {
        assertLightDarkSnapshots(
            of: NavigationView {
                VoiceToolsServerSettingsView(viewModel: VoiceToolsServerSettingsViewModel(
                    configuration: .init(isEnabled: true),
                    controller: nil,
                    state: .running(port: 10700)
                ))
            },
            drawHierarchyInKeyWindow: true
        )
    }

    @MainActor @Test func failed() {
        assertLightDarkSnapshots(
            of: NavigationView {
                VoiceToolsServerSettingsView(viewModel: VoiceToolsServerSettingsViewModel(
                    configuration: .init(isEnabled: true),
                    controller: nil,
                    state: .failed(message: "Address already in use")
                ))
            },
            drawHierarchyInKeyWindow: true
        )
    }

    /// Speech recognition is the half of the service that needs a permission, so the screen has to
    /// say when only text-to-speech will answer.
    @MainActor @Test func withoutSpeechRecognitionPermission() {
        assertLightDarkSnapshots(
            of: NavigationView {
                VoiceToolsServerSettingsView(viewModel: VoiceToolsServerSettingsViewModel(
                    configuration: .init(isEnabled: true),
                    controller: nil,
                    state: .running(port: 10700),
                    isSpeechRecognitionAuthorized: false
                ))
            },
            drawHierarchyInKeyWindow: true
        )
    }
}
