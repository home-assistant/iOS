import UIKit

/// A protocol for opening URLs, allowing for easy mocking and testing.
protocol URLOpening {
    /// Opens the specified URL.
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - options: A dictionary of options to use when opening the URL.
    ///   - completion: An optional completion handler to call when the operation completes.
    func open(
        _ url: URL,
        options: [UIApplication.OpenExternalURLOptionsKey: Any],
        completionHandler completion: ((Bool) -> Void)?
    )

    /// Returns a Boolean value indicating whether an app is available to handle a URL scheme.
    /// - Parameter url: A URL (Universal Resource Locator). The URL's scheme is used to identify the app that can open
    /// the URL.
    /// - Returns: false if there is no app installed for handling the URL's scheme, or if you have not declared the
    /// URL's scheme in your Info.plist; otherwise, true.
    func canOpenURL(_ url: URL) -> Bool

    /// Opens the app's settings at a specific destination.
    /// - Parameters:
    ///   - destination: The specific settings destination to navigate to.
    ///   - completionHandler: An optional completion handler that is called when the operation completes.
    ///                        The handler receives a Boolean value indicating whether the settings were successfully
    /// opened.
    func openSettings(destination: OpenSettingsDestination, completionHandler: ((Bool) -> Void)?)
}

/// A singleton responsible for opening URLs in the application.
/// This abstraction allows for easier testing and centralized URL opening logic.
final class URLOpener: URLOpening {
    /// The shared singleton instance.
    static let shared: URLOpening = URLOpener()

    /// Private initializer to enforce singleton pattern.
    private init() {}

    /// Opens the specified URL.
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - options: A dictionary of options to use when opening the URL.
    ///   - completion: An optional completion handler to call when the operation completes.
    func open(
        _ url: URL,
        options: [UIApplication.OpenExternalURLOptionsKey: Any] = [:],
        completionHandler completion: ((Bool) -> Void)? = nil
    ) {
        UIApplication.shared.open(url, options: options, completionHandler: completion)
    }

    /// Returns a Boolean value indicating whether an app is available to handle a URL scheme.
    /// - Parameter url: A URL (Universal Resource Locator). The URL's scheme is used to identify the app that can open
    /// the URL.
    /// - Returns: false if there is no app installed for handling the URL's scheme, or if you have not declared the
    /// URL's scheme in your Info.plist; otherwise, true.
    func canOpenURL(_ url: URL) -> Bool {
        UIApplication.shared.canOpenURL(url)
    }

    func openSettings(destination: OpenSettingsDestination, completionHandler: ((Bool) -> Void)? = nil) {
        if let url = destination.url {
            open(url, options: [:], completionHandler: completionHandler)
        } else {
            completionHandler?(false)
        }
    }
}

// MARK: - Mock for Testing

#if DEBUG
/// A mock URL opener for testing purposes.
final class MockURLOpener: URLOpening {
    var openedURLs: [(url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any])] = []
    var canOpenURLResult: Bool = true
    var openCompletionResult: Bool = true
    var openSettingsDestination: OpenSettingsDestination?

    func open(
        _ url: URL,
        options: [UIApplication.OpenExternalURLOptionsKey: Any] = [:],
        completionHandler completion: ((Bool) -> Void)? = nil
    ) {
        openedURLs.append((url, options))
        completion?(openCompletionResult)
    }

    func canOpenURL(_ url: URL) -> Bool {
        canOpenURLResult
    }

    func openSettings(destination: OpenSettingsDestination, completionHandler: ((Bool) -> Void)?) {
        openSettingsDestination = destination
        completionHandler?(true)
    }
}
#endif
