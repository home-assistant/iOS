import Foundation
import Speech

/// The locales that support on-device speech recognition.
///
/// Working them out instantiates one `SFSpeechRecognizer` per locale the system knows about, and
/// every `supportsOnDeviceRecognition` read is a synchronous XPC round trip to the speech daemon —
/// close to a second in total on a phone in Low Power Mode. The actor serializes callers so the
/// probe always runs off the main thread and its answer is reused: `locales()` never probes twice,
/// which means a dictation language installed while the app runs stays missing from it until
/// something asks for `refreshedLocales()`. Never build this list from a view body or any other
/// main-thread path.
actor SupportedSpeechLocales {
    static let shared = SupportedSpeechLocales()

    private let probe: @Sendable () -> [Locale]
    private var cachedLocales: [Locale]?
    private var runningProbe: Task<[Locale], Never>?

    /// The probe is injectable so a test can change what the device supports between two probes,
    /// which no test runner can do to the real speech daemon.
    init(probe: @escaping @Sendable () -> [Locale] = SupportedSpeechLocales.probeSystemLocales) {
        self.probe = probe
    }

    /// The locales as of the last probe, probing only when there has not been one yet.
    func locales() async -> [Locale] {
        if let cached = cachedLocales {
            return cached
        }
        return await probeLocales()
    }

    /// Probes again even when an answer is already cached, and replaces it, so every later
    /// `locales()` caller sees a language that was installed since the last probe.
    func refreshedLocales() async -> [Locale] {
        await probeLocales()
    }

    private func probeLocales() async -> [Locale] {
        if let running = runningProbe {
            return await running.value
        }

        let probe = probe
        let running = Task.detached(priority: .userInitiated) { probe() }
        runningProbe = running
        let locales = await running.value
        cachedLocales = locales
        runningProbe = nil
        return locales
    }

    static func probeSystemLocales() -> [Locale] {
        SFSpeechRecognizer.supportedLocales()
            .filter { SFSpeechRecognizer(locale: $0)?.supportsOnDeviceRecognition == true }
            .sorted { $0.identifier < $1.identifier }
    }
}
