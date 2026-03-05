import Combine
import Foundation
import Speech

final class AssistSettingsViewModel: ObservableObject {
    @Published var configuration: AssistConfiguration

    private(set) var availableLanguages: [String] = []
    private var cancellables = Set<AnyCancellable>()

    var isSelectedLanguageSupported: Bool {
        let lang = configuration.sttLanguage
        if lang.isEmpty { return true }
        return availableLanguages.contains(lang)
    }

    init() {
        self.configuration = AssistConfiguration.config
        self.availableLanguages = Self.supportedLocaleIdentifiers()

        $configuration
            .dropFirst() // Skip the initial value set in init
            .sink { config in
                config.save()
            }
            .store(in: &cancellables)
    }

    func displayName(for localeIdentifier: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forIdentifier: localeIdentifier) ?? localeIdentifier
    }

    private static func supportedLocaleIdentifiers() -> [String] {
        SFSpeechRecognizer.supportedLocales()
            .map(\.identifier)
            .sorted { lhs, rhs in
                let locale = Locale.current
                let lhsName = locale.localizedString(forIdentifier: lhs) ?? lhs
                let rhsName = locale.localizedString(forIdentifier: rhs) ?? rhs
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }
    }
}
