import Foundation

/// Identifiers for the one-time move from the app published under the original Apple Developer
/// account to the app that replaces it under the new one.
///
/// Both apps are built from this repository, so every value here has to name the *other* side as
/// well as this one; `AppMigrationRole` decides which side the running build plays.
///
/// - Important: the placeholder values marked below have to be replaced with the real identifiers
///   registered in the new Apple Developer account before the migration ships. `isConfigured`
///   returns `false` while any of them is still a placeholder, which keeps the whole flow hidden.
public enum AppMigrationConstants {
    /// Bundle identifier of the app being replaced. Development builds append `.dev`, so this is
    /// matched as a prefix rather than compared exactly.
    public static let sourceBundleID = "io.robbie.HomeAssistant"

    /// Bundle identifier of the app taking over.
    /// TODO: replace with the identifier registered in the new Apple Developer account.
    public static let destinationBundleID = "io.robbie.HomeAssistant.next"

    /// Custom URL scheme the app being replaced answers on.
    public static let sourceURLScheme = "homeassistant"

    /// Custom URL scheme the new app answers on. It *must* differ from `sourceURLScheme`: while both
    /// apps are installed, iOS picks an arbitrary winner for a scheme they both claim, so reusing it
    /// would make deep links — and this handoff — land in an unpredictable app.
    /// TODO: replace with the scheme the new app declares in its Info.plist.
    public static let destinationURLScheme = "homeassistant-next"

    /// Base URL of the universal link that carries the handoff, once the new account's domain serves
    /// an `apple-app-site-association` naming the new app.
    ///
    /// This is the preferred transport: a universal link can only be claimed by the app the domain
    /// vouches for, whereas any installed app may register `destinationURLScheme` and intercept the
    /// payload. The payload travels in the URL fragment, which is never sent to the server, so the
    /// Safari fallback (new app not installed) leaks nothing.
    /// TODO: set once the new account's domain hosts the association file.
    public static let destinationUniversalLinkBase: URL? = nil

    /// Where to send the user when the new app is not installed yet.
    /// TODO: replace with the new app's App Store product page.
    public static let destinationAppStoreURL = URL(string: "https://apps.apple.com/app/id000000000")!

    /// Host of the handoff URL the new app receives.
    public static let importHost = "migrate"

    /// Host of the acknowledgement the new app sends back to the app being replaced.
    public static let completionHost = "migration-complete"

    /// Host the new app uses to ask for the next slice of a payload that did not fit in one link.
    public static let continueHost = "migration-continue"

    /// Query item carrying how many servers the new app imported, for the acknowledgement.
    public static let importedServerCountQueryItem = "servers"

    /// Query items identifying which slice of which handoff to send next.
    public static let sessionQueryItem = "session"
    public static let nextChunkQueryItem = "next"

    /// How much encoded payload travels in one link. Neither `openURL` nor Safari document an upper
    /// bound on URL length, and an over-long one is truncated silently rather than rejected, so this
    /// stays well inside what is known to work; anything larger is handed over a slice at a time.
    public static let maximumChunkLength = 32_000

    /// A backstop on the number of round trips. At `maximumChunkLength` each, this is far more than
    /// any real configuration produces — it exists so a corrupt payload cannot bounce the user
    /// between the two apps indefinitely.
    public static let maximumChunkCount = 64

    /// Whether the placeholders above have been replaced with real values. Everything user-facing in
    /// the migration flow is hidden while this is `false`, so a build that forgot to configure it
    /// cannot show the user a button that opens nothing.
    public static var isConfigured: Bool {
        destinationBundleID != "io.robbie.HomeAssistant.next"
            && destinationURLScheme != "homeassistant-next"
            && destinationURLScheme != sourceURLScheme
            && destinationAppStoreURL.absoluteString != "https://apps.apple.com/app/id000000000"
    }
}
