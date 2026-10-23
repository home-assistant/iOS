import Shared
import WebKit

/// Copies the frontend WebView's cookies into the cookie storage used by native requests.
///
/// WebKit keeps its cookies in its own store, and `URLSession` cannot read it. Without this, a
/// cookie issued to the frontend by an authentication proxy never reaches native requests. The
/// Android app's HTTP client reads its WebView's cookie manager for the same reason.
///
/// The copy only adds cookies, never deletes them. The native storage persists on disk, and the
/// first read at launch can come back empty before WebKit has loaded its store, so deleting
/// whatever that read lacks would wipe the native cookies at every launch.
///
/// A cookie that the WebView deletes early, on logout for instance, therefore stays with native
/// requests until it expires.
final class WebViewCookieMirror: NSObject, WKHTTPCookieStoreObserver {
    static let shared = WebViewCookieMirror()

    @MainActor
    func start() {
        let store = WKWebsiteDataStore.default().httpCookieStore
        store.add(self)
        cookiesDidChange(in: store)
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { cookies in
            cookies.forEach(HANetworkingEnvironment.current.cookieStorage.setCookie)
            Current.Log.verbose("Mirrored \(cookies.count) WebView cookies to the native cookie storage")
        }
    }
}
