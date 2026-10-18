import Foundation
@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// Opens the screen the way the settings list does — probing for itself rather than showing the
/// injected list the snapshots use — which is the only path that decides whether a language
/// installed while the app runs is ever found.
@MainActor
struct VoiceToolsServerLanguagesViewRenderTests {
    private let english = [Locale(identifier: "en-US")]
    private let englishAndPortuguese = [Locale(identifier: "en-US"), Locale(identifier: "pt-BR")]

    /// The list is already cached by the time the screen opens, as it is once Home Assistant has
    /// asked the server to describe itself. Opening the screen has to probe again anyway, and leave
    /// the new answer behind for the next `describe`.
    @Test(.timeLimit(.minutes(1))) func openingTheScreenFindsALanguageInstalledSinceTheLastProbe() async throws {
        let stub = SpeechLocaleProbeStub(answers: [english, englishAndPortuguese])
        let speechLocales = SupportedSpeechLocales(probe: stub.probe)
        let cached = await speechLocales.locales()
        #expect(cached == english)

        // Laid out in a window, which is what makes SwiftUI run the view's `task`. Deliberately
        // never the key window: the snapshot helpers draw into whatever window is key.
        let controller = UIHostingController(
            rootView: NavigationView { VoiceToolsServerLanguagesView(speechLocales: speechLocales) }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        // The screen probes from its own task, so the new answer lands some time after the layout
        // pass. A screen that read the cache instead would never get here, and the time limit is
        // what fails the test.
        var advertised = await speechLocales.locales()
        while advertised != englishAndPortuguese {
            try await Task.sleep(nanoseconds: 10_000_000)
            advertised = await speechLocales.locales()
        }

        #expect(stub.probeCount == 2)
    }
}
