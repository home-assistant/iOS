import Foundation
@testable import HomeAssistant
import Shared
import Testing
import WebKit

/// `WebViewCookieMirror` copies cookies from a `WKHTTPCookieStore` into the native cookie storage,
/// additively and without deleting anything already there.
@MainActor
struct WebViewCookieMirrorTests {
    private let storage = HANetworkingEnvironment.current.cookieStorage

    private func makeCookie(name: String, value: String) -> HTTPCookie {
        HTTPCookie(properties: [
            .name: name,
            .value: value,
            .domain: "example.com",
            .path: "/",
        ])!
    }

    private func setCookie(_ cookie: HTTPCookie, in cookieStore: WKHTTPCookieStore) async {
        await withCheckedContinuation { continuation in
            cookieStore.setCookie(cookie) { continuation.resume() }
        }
    }

    /// Returns once `cookieStore` has handled every request sent to it before this call.
    ///
    /// The store answers requests in order, so a read sent now comes back after the mirror's own
    /// read has been answered, and after an observer added by `start()` has been registered.
    private func awaitPendingRequests(_ cookieStore: WKHTTPCookieStore) async {
        _ = await cookieStore.allCookies()
    }

    private func nativeValue(of name: String) -> String? {
        storage.cookies?.first { $0.name == name }?.value
    }

    @Test("A cookie already in the native storage survives an empty WebView read")
    func keepsExistingCookiesOnEmptyRead() async throws {
        let cookie = makeCookie(name: "webview_cookie_mirror_test_existing", value: "1")
        storage.setCookie(cookie)
        defer { storage.deleteCookie(cookie) }

        // `start()` always reads the default store, which a test cannot empty, so this hands the
        // observer callback an empty store directly.
        let dataStore = WKWebsiteDataStore.nonPersistent()
        WebViewCookieMirror().cookiesDidChange(in: dataStore.httpCookieStore)
        await awaitPendingRequests(dataStore.httpCookieStore)

        #expect(nativeValue(of: cookie.name) == "1")
    }

    @Test("start() copies whatever the WebView already holds")
    func startCopiesInitialSnapshot() async throws {
        let cookie = makeCookie(name: "webview_cookie_mirror_test_start", value: "1")
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        defer {
            storage.deleteCookie(cookie)
            cookieStore.delete(cookie)
        }
        await setCookie(cookie, in: cookieStore)

        WebViewCookieMirror().start()
        await awaitPendingRequests(cookieStore)

        #expect(nativeValue(of: cookie.name) == "1")
    }

    @Test("A renewed cookie replaces the old value under the same name")
    func replacesRenewedCookie() async throws {
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        let stale = makeCookie(name: "webview_cookie_mirror_test_renew", value: "old")
        let renewed = makeCookie(name: "webview_cookie_mirror_test_renew", value: "new")
        storage.setCookie(stale)
        defer {
            storage.deleteCookie(renewed)
            cookieStore.delete(renewed)
        }
        await setCookie(renewed, in: cookieStore)

        WebViewCookieMirror().start()
        await awaitPendingRequests(cookieStore)

        #expect(nativeValue(of: renewed.name) == "new")
    }

    @Test("start() also copies a cookie the WebView sets afterward")
    func startObservesLaterChanges() async throws {
        let cookie = makeCookie(name: "webview_cookie_mirror_test_observer", value: "1")
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        defer {
            storage.deleteCookie(cookie)
            cookieStore.delete(cookie)
        }

        // `WKHTTPCookieStore.add(_:)` keeps only a weak reference to its observer, so a mirror
        // that goes out of scope right after `start()` would stop receiving changes.
        let sut = WebViewCookieMirror()
        sut.start()
        await awaitPendingRequests(cookieStore)
        await setCookie(cookie, in: cookieStore)

        // The observer callback arrives whenever WebKit delivers it, and the mirror reports nothing
        // once it has copied, so this checks the storage every 20 ms for up to five seconds.
        let deadline = Date().addingTimeInterval(5)
        while nativeValue(of: cookie.name) != "1" {
            try #require(Date() < deadline, "The cookie set after start() never reached the native storage")
            try await Task.sleep(for: .milliseconds(20))
        }
        withExtendedLifetime(sut) {}
    }
}
