@testable import HomeAssistant
import Testing

struct WebRTCRemoteCandidateStagingTests {
    private func decide(
        _ staging: inout WebRTCRemoteCandidateStaging,
        address: String,
        type: String = "host",
        transport: String = "udp",
        port: Int = 5000,
        sdpMid: String? = "0"
    ) -> WebRTCRemoteCandidateStaging.Decision {
        staging.decision(
            for: "candidate:1 1 \(transport) 2130706431 \(address) \(port) typ \(type) generation 0",
            sdpMid: sdpMid,
            sdpMLineIndex: 0
        )
    }

    @Test(arguments: [
        "10.0.0.5",
        "172.16.4.1",
        "172.31.255.254",
        "192.168.1.20",
        "169.254.10.1",
        "127.0.0.1",
        "fd12:3456::1",
        "FE80::1c2:3ff",
        "::1",
        "5f2a9c1e-7d41-4b0a-9c55-1f0f6f1f6a11.local",
    ])
    func aPrivateHostIsHeld(address: String) {
        var staging = WebRTCRemoteCandidateStaging()

        let decision = decide(&staging, address: address)

        #expect(decision == .hold)
    }

    @Test(arguments: [
        "203.0.113.7",
        "172.15.0.1",
        "172.32.0.1",
        "192.169.1.1",
        "100.64.0.3",
        "2001:db8::1",
        "::",
        "camera.example.com",
        "1.2.3",
    ])
    func aPublicHostIsAdded(address: String) {
        var staging = WebRTCRemoteCandidateStaging()

        let decision = decide(&staging, address: address)

        #expect(decision == .add)
    }

    @Test(arguments: ["srflx", "prflx", "relay"])
    func onlyHostCandidatesAreHeld(type: String) {
        var staging = WebRTCRemoteCandidateStaging()

        let decision = decide(&staging, address: "192.168.1.20", type: type)

        #expect(decision == .add)
    }

    @Test func aRepeatedCandidateIsDropped() {
        var staging = WebRTCRemoteCandidateStaging()

        let first = decide(&staging, address: "203.0.113.7")
        let repeated = decide(&staging, address: "203.0.113.7")
        let repeatedInUppercase = decide(&staging, address: "203.0.113.7", transport: "UDP")
        let otherTransport = decide(&staging, address: "203.0.113.7", transport: "tcp")
        let otherPort = decide(&staging, address: "203.0.113.7", port: 5001)
        let otherType = decide(&staging, address: "203.0.113.7", type: "srflx")
        let otherMid = decide(&staging, address: "203.0.113.7", sdpMid: "1")
        let noMid = decide(&staging, address: "203.0.113.7", sdpMid: nil)
        let privateHost = decide(&staging, address: "192.168.1.20")
        let repeatedPrivateHost = decide(&staging, address: "192.168.1.20")

        #expect(first == .add)
        #expect(repeated == .drop)
        #expect(repeatedInUppercase == .drop)
        #expect(otherTransport == .add)
        #expect(otherPort == .add)
        #expect(otherType == .add)
        #expect(otherMid == .add)
        #expect(noMid == .add)
        #expect(privateHost == .hold)
        #expect(repeatedPrivateHost == .drop)
    }

    @Test func nothingIsHeldOnceHoldingStops() {
        var staging = WebRTCRemoteCandidateStaging()
        staging.holdsPrivateHosts = false

        let first = decide(&staging, address: "192.168.1.20")
        let repeated = decide(&staging, address: "192.168.1.20")

        #expect(first == .add)
        #expect(repeated == .drop)
    }

    @Test(arguments: ["candidate:1 1 udp", "candidate:1 1 udp 1 10.0.0.5 5000 host typ"])
    func aCandidateThatCannotBeReadIsAlwaysAdded(sdp: String) {
        var staging = WebRTCRemoteCandidateStaging()

        let first = staging.decision(for: sdp, sdpMid: "0", sdpMLineIndex: 0)
        let repeated = staging.decision(for: sdp, sdpMid: "0", sdpMLineIndex: 0)

        #expect(first == .add)
        #expect(repeated == .add)
    }
}
