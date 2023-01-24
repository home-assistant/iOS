import Foundation

extension Locale {
    var asIntentLanguage: IntentLanguage {
        .init(identifier: identifier, display: localizedString(forIdentifier: identifier) ?? identifier)
    }

    var intentLanguages: [IntentLanguage] {
        Locale.availableIdentifiers.map {
            IntentLanguage(identifier: $0, display: localizedString(forIdentifier: $0) ?? $0)
        }.sorted(by: { a, b in
            a.displayString.localizedCaseInsensitiveCompare(b.displayString) == .orderedAscending
        })
    }
}
