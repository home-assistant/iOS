import Foundation
import Shared
import SwiftUI

/// The locales this device transcribes on device, which is exactly what it advertises to Home
/// Assistant as speech-to-text languages.
struct VoiceToolsServerLanguagesView: View {
    /// `nil` while the locales are still being probed.
    @State private var locales: [Locale]?

    init() {}

    /// Injectable so previews and snapshot tests render a fixed list instead of probing the speech
    /// daemon on the machine rendering them.
    init(locales: [Locale]) {
        self._locales = State(initialValue: locales)
    }

    var body: some View {
        List {
            if let locales {
                if locales.isEmpty {
                    Section {
                        Text(L10n.Settings.VoiceToolsServer.Languages.empty)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(locales, id: \.identifier) { locale in
                            HStack {
                                Text(displayName(for: locale))
                                Spacer()
                                Text(locale.identifier)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } footer: {
                        Text(L10n.Settings.VoiceToolsServer.Languages.footer)
                    }
                }
            }
        }
        .overlay {
            if locales == nil {
                ProgressView()
            }
        }
        .navigationTitle(L10n.Settings.VoiceToolsServer.Languages.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard locales == nil else { return }
            let supported = await SupportedSpeechLocales.shared.locales()
            locales = supported.sorted { displayName(for: $0) < displayName(for: $1) }
        }
    }

    private func displayName(for locale: Locale) -> String {
        (Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier).capitalizedFirst
    }
}

#Preview("Languages") {
    NavigationView {
        VoiceToolsServerLanguagesView(locales: [
            Locale(identifier: "en-US"),
            Locale(identifier: "en-GB"),
            Locale(identifier: "pt-BR"),
            Locale(identifier: "de-DE"),
        ])
    }
}

#Preview("None") {
    NavigationView {
        VoiceToolsServerLanguagesView(locales: [])
    }
}
