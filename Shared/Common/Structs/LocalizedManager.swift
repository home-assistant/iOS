import Foundation
#if canImport(Lokalise) && !targetEnvironment(macCatalyst)
import Lokalise
#endif

public class LocalizedManager {
    #if canImport(Lokalise) && !targetEnvironment(macCatalyst)
    let lokalise: Lokalise
    #endif
    let bundle: Bundle

    init() {
        bundle = Bundle(for: Self.self)

        #if canImport(Lokalise) && !targetEnvironment(macCatalyst)
        self.lokalise = with(Lokalise.shared) {
            $0.setProjectID(
                "834452985a05254348aee2.46389241",
                token: "fe314d5c54f3000871ac18ccac8b62b20c143321"
            )
            // applies to e.g. storyboards and whatnot, but not L10n-read strings
            $0.swizzleMainBundle()
        }
        #endif
    }

    public func updateTranslations() {
        #if canImport(Lokalise) && !targetEnvironment(macCatalyst)
        var lokaliseEnv: LokaliseLocalizationType {
            if Current.settingsStore.prefs.bool(forKey: "showTranslationKeys") {
                return .debug
            }
            switch Current.appConfiguration {
            case .Release:
                if Current.isTestFlight {
                    return .prerelease
                } else {
                    return .release
                }
            case .Beta:
                return .prerelease
            case .Debug, .FastlaneSnapshot:
                return .local
            }
        }

        Current.Log.info("setting localization type to \(lokaliseEnv.rawValue)")

        lokalise.localizationType = lokaliseEnv
        lokalise.checkForUpdates(completion: { success, error in
            Current.Log.info("lokalise updated: \(success) \(String(describing: error))")
        })
        #endif
    }

    public func string(_ key: String, _ table: String) -> String {
        var bundleVersion: String {
            bundle.localizedString(forKey: key, value: nil, table: table)
        }

        #if canImport(Lokalise) && !targetEnvironment(macCatalyst)
            let lokaliseVersion = lokalise.localizedString(forKey: key, value: nil, table: table)
            if lokaliseVersion != key || lokalise.localizationType == .debug {
                return lokaliseVersion
            } else {
                return bundleVersion
            }
        #else
            return bundleVersion
        #endif
    }
}
