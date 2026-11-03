@testable import HomeAssistant
import Shared

/// Runs `body` with `URLOpener.shared` swapped for a `MockURLOpener` and links set to open in Safari,
/// so `openURLInBrowser` hands them to the opener instead of leaving the app or presenting an in-app
/// browser. Callers swap process-wide state, so their suite carries `.sharedState`.
@MainActor
enum RecordingURLOpener {
    static func with<T>(_ body: (MockURLOpener) async throws -> T) async rethrows -> T {
        let previousOpener = URLOpener.shared
        let previousBrowser = prefs.object(forKey: "openInBrowser")
        let opener = MockURLOpener()
        URLOpener.shared = opener
        prefs.set(OpenInBrowser.Safari.rawValue, forKey: "openInBrowser")
        defer {
            URLOpener.shared = previousOpener
            prefs.set(previousBrowser, forKey: "openInBrowser")
        }
        return try await body(opener)
    }
}
