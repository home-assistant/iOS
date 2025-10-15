import Foundation
@testable import HomeAssistant
import Network
import Shared
import Testing

@Suite("URL Extensions Tests")
struct URLExtensionsTests {
    @Test(
        "Given local URLs when checking isLocal then returns true",
        arguments: [
            "http://homeassistant.local:8123",
            "http://homeassistant.LOCAL:8123",
            "http://homeassistant.LoCaL:42",
            "https://homeassistant.local",
            "http://homeassistant.lan:8123",
            "http://homeassistant.home:8123",
            "http://homeassistant.internal:8123",
            "http://homeassistant.localdomain:8123",
            "http://homeassistant.local:8123/lovelace/default",
            "http://my.homeassistant.local:8123",
            "http://localhost:8123",
            "http://127.0.0.1:8123",
            "http://192.168.1.10:8123",
            "http://10.0.0.10:8123",
            "http://172.16.0.1:8123",
            "http://172.31.255.255:8123", // Edge of 172.16.0.0/12 range
            "http://[::1]:8123",
            "http://169.254.1.1:8123", // link local IP
            "file:///Users/test/file.txt", // file URL
        ]
    )
    func localURLsAreLocal(urlString: String) async throws {
        let url = try #require(URL(string: urlString))
        #expect(url.isLocal == true, "URL \(urlString) should be local")
        #expect(url.isRemote == false, "URL \(urlString) should not be remote")
    }

    @Test(
        "Given remote URLs when checking isLocal then returns false",
        arguments: [
            "https://www.home-assistant.io",
            "https://google.com:443",
            "http://example.com",
            "https://github.com",
            "http://8.8.8.8:80", // Google DNS
            "https://1.1.1.1", // Cloudflare DNS
            "http://208.67.222.222", // OpenDNS
            "https://my-homeassistant.duckdns.org",
            "https://subdomain.example.org:8080",
            "http://172.15.0.1", // Just outside private range
            "http://172.32.0.1", // Just outside private range
            "http://192.167.1.1", // Just outside private range
            "http://192.169.1.1", // Just outside private range
        ]
    )
    func remoteURLsAreRemote(urlString: String) async throws {
        let url = try #require(URL(string: urlString))
        #expect(url.isLocal == false, "URL \(urlString) should not be local")
        #expect(url.isRemote == true, "URL \(urlString) should be remote")
    }

    @Test(
        "Given IPv6 URLs when checking locality",
        arguments: [
            ("http://[fe80::1]:8123", true), // Link-local
            ("http://[fe80::dead:beef]:8123", true), // Link-local
            ("http://[::1]:8123", true), // Loopback
            ("http://[2001:db8::1]:8123", false), // Global unicast (documentation range but not private)
            ("http://[2607:f8b0:4004:c1b::65]:8123", false), // Google's IPv6
        ]
    )
    func ipv6URLLocality(urlString: String, expectedLocal: Bool) async throws {
        let url = try #require(URL(string: urlString))
        #expect(url.isLocal == expectedLocal, "URL \(urlString) locality should be \(expectedLocal)")
        #expect(url.isRemote == !expectedLocal, "URL \(urlString) remoteness should be \(!expectedLocal)")
    }

    @Test("Given edge case URLs when checking locality")
    func edgeCaseURLs() async throws {
        // File URL with no host
        let fileURL = try #require(URL(string: "file:///path/to/file"))
        #expect(fileURL.isLocal == true, "File URLs should be local")
        #expect(fileURL.isRemote == false, "File URLs should not be remote")

        // URL with no host but not file scheme
        let dataURL = try #require(URL(string: "data:text/plain;base64,SGVsbG8="))
        #expect(dataURL.isLocal == false, "Data URLs should not be local (no file scheme)")
        #expect(dataURL.isRemote == true, "Data URLs should be remote")
    }

    @Test(
        "Given various private IP ranges when checking isLocal then returns true",
        arguments: [
            "http://10.0.0.1:8123", // Start of 10.0.0.0/8
            "http://10.255.255.255:8123", // End of 10.0.0.0/8
            "http://172.16.0.1:8123", // Start of 172.16.0.0/12
            "http://172.31.255.254:8123", // End of 172.16.0.0/12
            "http://192.168.0.1:8123", // Start of 192.168.0.0/16
            "http://192.168.255.254:8123", // End of 192.168.0.0/16
            "http://169.254.0.1:8123", // Start of link-local
            "http://169.254.255.254:8123", // End of link-local
        ]
    )
    func privateIPRangesAreLocal(urlString: String) async throws {
        let url = try #require(URL(string: urlString))
        #expect(url.isLocal == true, "Private IP \(urlString) should be local")
        #expect(url.isRemote == false, "Private IP \(urlString) should not be remote")
    }
}
