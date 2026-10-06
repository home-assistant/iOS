import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

// Serialized: the tests mutate process-wide app-group defaults through `Current.settingsStore`.
@Suite(.serialized)
struct WebKitEnhancedSecurityTests {
    // MARK: - Which URLs WebKit would harden

    @Test(arguments: [
        "http://192.168.1.10:8123",
        "http://10.0.0.5:8123",
        "http://172.16.4.2:8123",
        "http://homeassistant.local:8123",
        "http://example.com",
        // Close enough to loopback to be worth pinning: neither is 127.*.*.* or a localhost name.
        "http://127.0.0.1.example.com",
        "http://1270.0.0.1",
    ])
    func plainHTTPHostsAreSubjectToEnhancedSecurity(urlString: String) {
        let url = URL(string: urlString)!
        #expect(WebKitEnhancedSecurity.isSubjectToEnhancedSecurity(url))
    }

    @Test(arguments: [
        // HTTPS is never a candidate, wherever it points.
        "https://192.168.1.10:8123",
        "https://example.ui.nabu.casa",
        // WebKit exempts localhost and loopback, which is what makes a loopback proxy a way out.
        "http://127.0.0.1:8123",
        "http://127.1.2.3:8123",
        "http://localhost:8123",
        "http://LOCALHOST:8123",
        "http://foo.localhost:8123",
        "http://[::1]:8123",
    ])
    func loopbackAndSecureURLsAreExempt(urlString: String) {
        let url = URL(string: urlString)!
        #expect(!WebKitEnhancedSecurity.isSubjectToEnhancedSecurity(url))
    }

    // MARK: - Whether to write the override

    @Test func disablesHeuristicsWhenAnyURLIsPlainHTTP() {
        withEnhancedSecurityWorld(userWantsAppleDefault: false) {
            #expect(WebKitEnhancedSecurity.shouldDisableHeuristics(for: [
                URL(string: "https://example.ui.nabu.casa")!,
                URL(string: "http://192.168.1.10:8123")!,
            ]))
        }
    }

    @Test func leavesHeuristicsAloneForAnHTTPSOnlySetup() {
        withEnhancedSecurityWorld(userWantsAppleDefault: false) {
            #expect(!WebKitEnhancedSecurity.shouldDisableHeuristics(for: [
                URL(string: "https://example.ui.nabu.casa")!,
                URL(string: "https://192.168.1.10:8123")!,
            ]))
        }
    }

    @Test func leavesHeuristicsAloneWhenTheUserAsksForApplesDefault() {
        withEnhancedSecurityWorld(userWantsAppleDefault: true) {
            #expect(!WebKitEnhancedSecurity.shouldDisableHeuristics(for: [
                URL(string: "http://192.168.1.10:8123")!,
            ]))
        }
    }

    @Test func settingDefaultsToOffSoLocalDashboardsStayFast() {
        withEnhancedSecurityWorld(userWantsAppleDefault: false) {
            Current.settingsStore.prefs.removeObject(forKey: "enhancedWebSecurityEnabled")
            #expect(Current.settingsStore.enhancedWebSecurityEnabled == false)
        }
    }

    // MARK: - Writing the override

    @Test func writesTheOverrideForAPlainHTTPServer() {
        withEnhancedSecurityWorld(userWantsAppleDefault: false) {
            let defaults = isolatedDefaults()
            WebKitEnhancedSecurity.prepare(for: [URL(string: "http://192.168.1.10:8123")!], defaults: defaults)
            #expect(defaults.object(forKey: WebKitEnhancedSecurity.heuristicsDefaultsKey) as? Bool == false)
        }
    }

    @Test func clearsTheOverrideOnceNoURLNeedsIt() {
        withEnhancedSecurityWorld(userWantsAppleDefault: false) {
            let defaults = isolatedDefaults()
            WebKitEnhancedSecurity.prepare(for: [URL(string: "http://192.168.1.10:8123")!], defaults: defaults)
            // Server moved to HTTPS: the override has to be removed, not left behind turning a
            // security feature off for a setup that no longer suffers from it.
            WebKitEnhancedSecurity.prepare(for: [URL(string: "https://192.168.1.10:8123")!], defaults: defaults)
            #expect(defaults.object(forKey: WebKitEnhancedSecurity.heuristicsDefaultsKey) == nil)
        }
    }

    @Test func writesNothingForAnHTTPSOnlySetup() {
        withEnhancedSecurityWorld(userWantsAppleDefault: false) {
            let defaults = isolatedDefaults()
            WebKitEnhancedSecurity.prepare(for: [URL(string: "https://example.ui.nabu.casa")!], defaults: defaults)
            #expect(defaults.object(forKey: WebKitEnhancedSecurity.heuristicsDefaultsKey) == nil)
        }
    }

    // MARK: - Reading the configured servers

    @Test func collectsEveryURLAcrossConfiguredServers() {
        withServers([
            .init(externalURL: "https://external.example.com", internalURL: "http://192.168.1.10:8123"),
            .init(externalURL: nil, internalURL: "http://10.0.0.5:8123"),
        ]) {
            #expect(Set(WebKitEnhancedSecurity.configuredFrontendURLs().map(\.absoluteString)) == [
                "https://external.example.com",
                "http://192.168.1.10:8123",
                "http://10.0.0.5:8123",
            ])
        }
    }

    @Test func isRelevantOnlyWhenAServerUsesPlainHTTP() {
        withServers([.init(externalURL: "https://external.example.com", internalURL: "http://192.168.1.10:8123")]) {
            #expect(WebKitEnhancedSecurity.isRelevantForConfiguredServers())
        }
        withServers([.init(externalURL: "https://external.example.com", internalURL: "https://192.168.1.10:8123")]) {
            #expect(!WebKitEnhancedSecurity.isRelevantForConfiguredServers())
        }
        withServers([]) {
            #expect(!WebKitEnhancedSecurity.isRelevantForConfiguredServers())
        }
    }

    @Test func preparingForConfiguredServersWritesTheOverride() {
        withEnhancedSecurityWorld(userWantsAppleDefault: false) {
            withServers([.init(externalURL: nil, internalURL: "http://192.168.1.10:8123")]) {
                UserDefaults.standard.removeObject(forKey: WebKitEnhancedSecurity.heuristicsDefaultsKey)
                defer { UserDefaults.standard.removeObject(forKey: WebKitEnhancedSecurity.heuristicsDefaultsKey) }

                WebKitEnhancedSecurity.prepareForConfiguredServers()

                #expect(
                    UserDefaults.standard.object(forKey: WebKitEnhancedSecurity.heuristicsDefaultsKey) as? Bool == false
                )
            }
        }
    }

    // MARK: - Helpers

    private struct ServerURLs {
        var externalURL: String?
        var internalURL: String?
    }

    /// Swaps in a server manager holding exactly the URLs a case is about, and puts the real one
    /// back afterwards.
    private func withServers(_ servers: [ServerURLs], _ body: () -> Void) {
        let previous = Current.servers
        defer { Current.servers = previous }

        let manager = FakeServerManager(initial: 0)
        for (index, urls) in servers.enumerated() {
            let info = ServerInfo(
                name: "Server \(index)",
                connection: .init(
                    externalURL: urls.externalURL.flatMap(URL.init(string:)),
                    internalURL: urls.internalURL.flatMap(URL.init(string:)),
                    cloudhookURL: nil,
                    remoteUIURL: nil,
                    webhookID: "webhook-\(index)",
                    webhookSecret: nil,
                    internalSSIDs: nil,
                    internalHardwareAddresses: nil,
                    isLocalPushEnabled: false,
                    securityExceptions: .init(),
                    connectionAccessSecurityLevel: .lessSecure
                ),
                token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
                version: "2026.9"
            )
            manager.add(identifier: .init(rawValue: "server-\(index)"), serverInfo: info)
        }
        Current.servers = manager

        body()
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "WebKitEnhancedSecurityTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func withEnhancedSecurityWorld(userWantsAppleDefault: Bool, _ body: () -> Void) {
        let previous = Current.settingsStore.enhancedWebSecurityEnabled
        defer { Current.settingsStore.enhancedWebSecurityEnabled = previous }
        Current.settingsStore.enhancedWebSecurityEnabled = userWantsAppleDefault
        body()
    }
}
