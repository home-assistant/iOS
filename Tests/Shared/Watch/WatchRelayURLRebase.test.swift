import Foundation
@testable import Shared
import Testing

struct WatchRelayURLRebaseTests {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    private func connection(
        internalURL: String? = "http://homeassistant.local:8123",
        externalURL: String? = "https://ha.example.com",
        remoteUIURL: String? = nil,
        cloudhookURL: String? = nil
    ) -> ConnectionInfo {
        ConnectionInfo(
            externalURL: externalURL.map(url),
            internalURL: internalURL.map(url),
            cloudhookURL: cloudhookURL.map(url),
            remoteUIURL: remoteUIURL.map(url),
            webhookID: "webhook",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .lessSecure
        )
    }

    /// The reported bug: the watch can only ever resolve the external URL, and on a router without
    /// NAT loopback that URL doesn't route from inside the LAN. The phone re-bases it onto the
    /// internal URL it is itself using, keeping the path the watch built.
    @Test func rebasesExternalURLOntoThePhonesInternalURL() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://ha.example.com/api/services/light/toggle"),
            connection: connection(),
            activeURL: url("http://homeassistant.local:8123")
        )

        #expect(rebased?.absoluteString == "http://homeassistant.local:8123/api/services/light/toggle")
    }

    @Test func keepsQueryAndPathIntact() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://ha.example.com/api/states/light.kitchen?foo=bar"),
            connection: connection(),
            activeURL: url("http://homeassistant.local:8123")
        )

        #expect(rebased?.absoluteString == "http://homeassistant.local:8123/api/states/light.kitchen?foo=bar")
    }

    /// Nothing to change when the phone would dial the very base the watch already picked — the
    /// caller then sends the watch's URL untouched.
    @Test func returnsNilWhenAlreadyOnTheActiveURL() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://ha.example.com/api/services/light/toggle"),
            connection: connection(),
            activeURL: url("https://ha.example.com")
        )

        #expect(rebased == nil)
    }

    /// A cloudhook is an opaque endpoint, not a base the API hangs off, so its path can't be
    /// transplanted. It also already works from any network, so leaving it alone costs nothing.
    @Test func leavesCloudhookURLsAlone() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://hooks.nabu.casa/ABC123"),
            connection: connection(cloudhookURL: "https://hooks.nabu.casa/ABC123"),
            activeURL: url("http://homeassistant.local:8123")
        )

        #expect(rebased == nil)
    }

    /// A URL built on something the server doesn't have configured is not ours to rewrite.
    @Test func leavesUnrelatedHostsAlone() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://somewhere.else/api/states"),
            connection: connection(),
            activeURL: url("http://homeassistant.local:8123")
        )

        #expect(rebased == nil)
    }

    /// A bare string prefix would treat `ha.example.com.evil.test` as living under the configured
    /// external URL and rewrite a request meant for it.
    @Test func doesNotMatchAHostThatMerelyStartsWithTheBase() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://ha.example.com.evil.test/api/states"),
            connection: connection(),
            activeURL: url("http://homeassistant.local:8123")
        )

        #expect(rebased == nil)
    }

    /// Two bases on the same host, distinguished only by path: the longer one describes the request
    /// more precisely and must win, or the rebased path would keep a segment that isn't the base's.
    @Test func prefersTheLongestMatchingBase() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://ha.example.com/ha/api/states"),
            connection: connection(
                internalURL: "https://ha.example.com/ha",
                externalURL: "https://ha.example.com"
            ),
            activeURL: url("http://homeassistant.local:8123")
        )

        #expect(rebased?.absoluteString == "http://homeassistant.local:8123/api/states")
    }

    /// The base with no path of its own still matches, so a request to the bare root is rebased.
    @Test func rebasesAURLThatIsExactlyTheBase() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://ha.example.com"),
            connection: connection(),
            activeURL: url("http://homeassistant.local:8123")
        )

        #expect(rebased?.absoluteString == "http://homeassistant.local:8123")
    }

    /// A trailing slash on the stored URL is normalization noise, not a different base.
    @Test func matchesBasesStoredWithATrailingSlash() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://ha.example.com/api/states"),
            connection: connection(externalURL: "https://ha.example.com/"),
            activeURL: url("http://homeassistant.local:8123/")
        )

        #expect(rebased?.absoluteString == "http://homeassistant.local:8123/api/states")
    }

    // MARK: - What the phone is allowed to dial

    /// The relayed request carries the watch's bearer token, so an arbitrary host must never be
    /// dialed just because the message named a server the phone knows.
    @Test func refusesHostsTheServerIsNotConfiguredFor() {
        #expect(WatchRelayURLRebase.isPermitted(
            url("https://attacker.example/steal"),
            connection: connection()
        ) == false)
    }

    @Test func refusesAHostThatMerelyStartsWithAConfiguredBase() {
        #expect(WatchRelayURLRebase.isPermitted(
            url("https://ha.example.com.evil.test/api/states"),
            connection: connection()
        ) == false)
    }

    @Test func permitsEachConfiguredBase() {
        let connection = connection(remoteUIURL: "https://abc123.ui.nabu.casa")
        #expect(WatchRelayURLRebase.isPermitted(
            url("http://homeassistant.local:8123/api/states"),
            connection: connection
        ))
        #expect(WatchRelayURLRebase.isPermitted(url("https://ha.example.com/api/states"), connection: connection))
        #expect(WatchRelayURLRebase.isPermitted(url("https://abc123.ui.nabu.casa/api/states"), connection: connection))
    }

    /// The watch sends the cloudhook from its own registration, which the phone doesn't hold — a
    /// different path on the same host. Those requests carry no bearer token, so matching the host
    /// is enough.
    @Test func permitsTheCloudhookHostWithADifferentPath() {
        let connection = connection(cloudhookURL: "https://hooks.nabu.casa/PHONE_ID")
        #expect(WatchRelayURLRebase.isPermitted(url("https://hooks.nabu.casa/WATCH_ID"), connection: connection))
    }

    @Test func refusesTheCloudhookPathOnAnotherHost() {
        let connection = connection(cloudhookURL: "https://hooks.nabu.casa/PHONE_ID")
        #expect(WatchRelayURLRebase.isPermitted(
            url("https://hooks.nabu.casa.evil.test/WATCH_ID"),
            connection: connection
        ) == false)
    }

    /// Remote UI is a configured base like the others, so a watch that fell back to it is rebased
    /// too.
    @Test func rebasesRemoteUIURLs() {
        let rebased = WatchRelayURLRebase.rebased(
            url("https://abc123.ui.nabu.casa/api/states"),
            connection: connection(externalURL: nil, remoteUIURL: "https://abc123.ui.nabu.casa"),
            activeURL: url("http://homeassistant.local:8123")
        )

        #expect(rebased?.absoluteString == "http://homeassistant.local:8123/api/states")
    }
}
