import Foundation
import Shared

/// Opts this process out of WebKit's "Enhanced Security" heuristic when the frontend is reached over
/// plain HTTP.
///
/// iOS 27 renders any page loaded over `http://` in a hardened
/// `com.apple.WebKit.WebContent.EnhancedSecurity` process, which forces hardware memory tagging on
/// and makes allocation-heavy dashboards crawl. WebKit exempts loopback but *not* private LAN
/// ranges, so every instance reached at `http://<lan-ip>:8123` pays that cost while the same
/// dashboard over the Nabu Casa URL stays fast — which is exactly the split users report.
///
/// `EnhancedSecurityHeuristicsEnabled` is the preference behind it and is declared
/// `defaultsOverridable`, so writing the matching `WebKitDebug…` key into the standard user defaults
/// turns the heuristic off for this process. With it off WebKit skips both the per-navigation
/// tracking and the persisted record of domains that previously triggered it, so a server that was
/// already marked recovers without the user clearing anything.
///
/// Two constraints come out of how WebKit reads this:
///
/// - `WebPreferences::platformInitializeStore()` reads the key once, when a `WKWebView` is built, so
///   ``prepare(for:defaults:)`` has to run *before* construction, not after.
/// - It is read from `UserDefaults.standard`, not the app group suite that ``SettingsStore`` uses.
///
/// No version check gates this: the key is inert on releases that don't know it, and hard-coding a
/// floor would silently miss the behaviour if Apple back-ports it.
enum WebKitEnhancedSecurity {
    /// The global debug prefix (`WebKitDebug`) plus the preference name, which is the form WebKit
    /// falls back to when a `WKPreferences` has no user-defaults identifier of its own — the case
    /// for every web view this app builds.
    static let heuristicsDefaultsKey = "WebKitDebugEnhancedSecurityHeuristicsEnabled"

    /// Mirrors WebKit's `isURLCandidateForEnhancedSecurity`: plain HTTP, and not a host it treats as
    /// localhost or a loopback address.
    static func isSubjectToEnhancedSecurity(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "http" else { return false }
        guard let host = url.host else { return true }
        return !isLocalHostOrLoopbackAddress(host)
    }

    /// Mirrors WebCore's `SecurityOrigin::isLocalHostOrLoopbackIPAddress`.
    static func isLocalHostOrLoopbackAddress(_ host: String) -> Bool {
        let host = host.lowercased()

        // `URL.host` strips the brackets IPv6 literals carry in a URL string.
        if host == "::1" || host == "[::1]" {
            return true
        }

        if host == "localhost" || host.hasSuffix(".localhost") {
            return true
        }

        // 127.*.*.*, with every remaining character a digit.
        guard host.hasPrefix("127.") else { return false }
        let dots = host.filter { $0 == "." }.count
        return dots == 3 && host.allSatisfy { $0.isASCII && ($0.isNumber || $0 == ".") }
    }

    /// Writes or clears the override for the URLs a web view built right now might load.
    ///
    /// Call this immediately before building a `WKWebView`; it is a no-op when nothing about the
    /// configuration has changed.
    static func prepare(for urls: [URL], defaults: UserDefaults = .standard) {
        let wanted = shouldDisableHeuristics(for: urls)
        let current = defaults.object(forKey: heuristicsDefaultsKey) != nil

        guard wanted != current else { return }

        if wanted {
            defaults.set(false, forKey: heuristicsDefaultsKey)
            Current.Log
                .info(
                    "Disabling WebKit Enhanced Security heuristics: frontend is reached over plain HTTP"
                )
        } else {
            defaults.removeObject(forKey: heuristicsDefaultsKey)
            Current.Log.info("Restoring WebKit Enhanced Security heuristics to the system default")
        }
    }

    /// `true` when the user has not asked for Apple's default and at least one of `urls` would be
    /// pushed into the hardened process.
    static func shouldDisableHeuristics(for urls: [URL]) -> Bool {
        guard !Current.settingsStore.enhancedWebSecurityEnabled else { return false }
        return urls.contains(where: isSubjectToEnhancedSecurity)
    }

    /// Every URL the frontend web view could load across the servers already set up.
    ///
    /// The active URL alone is not enough: the app switches between internal and external URLs on
    /// network changes without rebuilding the web view, so the override has to cover any of them.
    static func configuredFrontendURLs() -> [URL] {
        Current.servers.all.flatMap(\.info.connection.configuredURLs)
    }

    /// Convenience for the frontend web view, which loads whichever server is active.
    static func prepareForConfiguredServers() {
        prepare(for: configuredFrontendURLs())
    }

    /// `true` when the override has something to act on, which is what decides whether the setting
    /// that turns it back off is worth showing at all.
    static func isRelevantForConfiguredServers() -> Bool {
        configuredFrontendURLs().contains(where: isSubjectToEnhancedSecurity)
    }
}
