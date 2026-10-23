import AVFoundation

public extension AVURLAsset {
    /// An asset for `url` that presents the cookies in `HANetworkingEnvironment.current.cookieStorage`.
    ///
    /// AVFoundation loads media over its own connection, which reads no `URLSessionConfiguration`, so
    /// without this a server behind cookie-based authentication rejects every media request.
    static func withMirroredCookies(url: URL) -> AVURLAsset {
        #if os(watchOS)
        // The watch has no WebView to mirror, so its storage never holds these cookies.
        return AVURLAsset(url: url)
        #else
        let cookies = HANetworkingEnvironment.current.cookieStorage.cookies(for: url) ?? []
        return AVURLAsset(url: url, options: [AVURLAssetHTTPCookiesKey: cookies])
        #endif
    }
}
