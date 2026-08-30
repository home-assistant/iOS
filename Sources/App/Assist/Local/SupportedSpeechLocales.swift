import Foundation
import Speech

/// The locales that support on-device speech recognition.
///
/// Working them out instantiates one `SFSpeechRecognizer` per locale the system knows about, and
/// every `supportsOnDeviceRecognition` read is a synchronous XPC round trip to the speech daemon —
/// close to a second in total on a phone in Low Power Mode. The actor serializes callers so the
/// probe runs at most once per process and always off the main thread, which means a dictation
/// language installed while the app runs only shows up after a relaunch. Never build this list
/// from a view body or any other main-thread path.
actor SupportedSpeechLocales {
    static let shared = SupportedSpeechLocales()

    private var cachedLocales: [Locale]?
    private var runningProbe: Task<[Locale], Never>?

    func locales() async -> [Locale] {
        if let cached = cachedLocales {
            return cached
        }
        if let probe = runningProbe {
            return await probe.value
        }

        let probe = Task.detached(priority: .userInitiated) { Self.probeSupportedLocales() }
        runningProbe = probe
        let locales = await probe.value
        cachedLocales = locales
        runningProbe = nil
        return locales
    }

    private static func probeSupportedLocales() -> [Locale] {
        SFSpeechRecognizer.supportedLocales()
            .filter { SFSpeechRecognizer(locale: $0)?.supportsOnDeviceRecognition == true }
            .sorted { $0.identifier < $1.identifier }
    }
}
