import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

struct DownloadManagerViewModelTests {
    private func cookie(
        name: String = "session",
        domain: String = "example.com",
        path: String = "/",
        secure: Bool = false
    ) -> HTTPCookie {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: "value",
            .domain: domain,
            .path: path,
        ]
        if secure {
            properties[.secure] = "TRUE"
        }
        return HTTPCookie(properties: properties)!
    }

    @Test func testMatchingCookieIsAddedToRequest() {
        let request = URLRequest(url: URL(string: "https://example.com/api/download")!)
        let result = DownloadManagerViewModel.request(request, addingCookies: [cookie()])
        #expect(result.value(forHTTPHeaderField: "Cookie") == "session=value")
    }

    @Test func testSubdomainCookieIsAddedForWildcardDomain() {
        let request = URLRequest(url: URL(string: "https://ha.example.com/api/download")!)
        let result = DownloadManagerViewModel.request(request, addingCookies: [cookie(domain: ".example.com")])
        #expect(result.value(forHTTPHeaderField: "Cookie") == "session=value")
    }

    @Test func testCookieForOtherDomainIsNotAdded() {
        let request = URLRequest(url: URL(string: "https://example.com/api/download")!)
        let result = DownloadManagerViewModel.request(request, addingCookies: [cookie(domain: "other.com")])
        #expect(result.value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test func testSecureCookieIsNotAddedOnPlainHTTP() {
        let request = URLRequest(url: URL(string: "http://example.com/api/download")!)
        let result = DownloadManagerViewModel.request(request, addingCookies: [cookie(secure: true)])
        #expect(result.value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test func testCookieWithNonMatchingPathIsNotAdded() {
        let request = URLRequest(url: URL(string: "https://example.com/api/download")!)
        let result = DownloadManagerViewModel.request(request, addingCookies: [cookie(path: "/admin")])
        #expect(result.value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test func testCookiePathMatchStopsAtSegmentBoundary() {
        // RFC 6265 §5.1.4: a cookie for /admin matches /admin/download but not /administrator.
        let boundary = URLRequest(url: URL(string: "https://example.com/administrator/download")!)
        let boundaryResult = DownloadManagerViewModel.request(boundary, addingCookies: [cookie(path: "/admin")])
        #expect(boundaryResult.value(forHTTPHeaderField: "Cookie") == nil)

        let nested = URLRequest(url: URL(string: "https://example.com/admin/download")!)
        let nestedResult = DownloadManagerViewModel.request(nested, addingCookies: [cookie(path: "/admin")])
        #expect(nestedResult.value(forHTTPHeaderField: "Cookie") == "session=value")

        let exact = URLRequest(url: URL(string: "https://example.com/admin")!)
        let exactResult = DownloadManagerViewModel.request(exact, addingCookies: [cookie(path: "/admin")])
        #expect(exactResult.value(forHTTPHeaderField: "Cookie") == "session=value")
    }

    @Test func testRequestWithoutCookiesIsUnchanged() {
        let request = URLRequest(url: URL(string: "https://example.com/api/download")!)
        let result = DownloadManagerViewModel.request(request, addingCookies: [])
        #expect(result == request)
    }
}
