import CryptoKit
import Foundation
@testable import HomeAssistant
import Testing

/// The contract between the two apps: every link survives its own URL, nothing without a session gets
/// in, the key survives the URL alphabet, a payload opens only with its key, and the previous app's
/// phase survives a relaunch.
struct AppMigrationLinkTests {
    private let session = AppMigrationSession.make()

    @Test func everyLinkRoundTripsThroughItsURL() {
        let links: [AppMigrationLink] = [
            .request(session),
            .payloadReady(sessionID: session.id, key: session.keyString),
            .payloadReady(sessionID: session.id, key: nil),
            .declined(sessionID: session.id, reason: nil),
            .declined(sessionID: session.id, reason: .previousAppErased),
            .restart(sessionID: session.id),
            .erase(sessionID: session.id),
            .erased(sessionID: session.id),
        ]
        for link in links {
            for role in [AppMigrationRole.newApp, .previousApp] {
                let url = link.url(to: role)
                #expect(url.scheme == role.urlScheme)
                #expect(AppMigrationLink(url: url) == link)
            }
        }
    }

    @Test func rejectsForeignHostsAndLinksWithoutASession() throws {
        let foreign = try #require(URL(string: "homeassistant-ohf-dev://navigate/lovelace/0"))
        #expect(AppMigrationLink(url: foreign) == nil)
        for path in ["restart", "erase", "erased", "declined", "payload"] {
            let url = try #require(URL(string: "homeassistant-ohf-dev://migration/\(path)"))
            #expect(AppMigrationLink(url: url) == nil, "\(path) must not be accepted without a session")
        }
        let requestWithoutKey =
            try #require(URL(string: "homeassistant-nc-dev://migration/request?session=\(UUID().uuidString)"))
        #expect(AppMigrationLink(url: requestWithoutKey) == nil)
    }

    @Test func sessionKeySurvivesTheURLAlphabet() {
        let restored = AppMigrationSession(id: session.id, keyString: session.keyString)
        #expect(restored == session)
        #expect(AppMigrationSession(id: session.id, keyString: "too-short") == nil)
    }

    @Test func sealedPayloadOpensOnlyWithItsKeyAndUntouched() throws {
        let data = Data("servers and sign-ins".utf8)
        let sealed = try AppMigrationCrypto.seal(data, key: session.key)
        let opened = try AppMigrationCrypto.open(sealed, key: session.key)
        #expect(opened == data)
        #expect(throws: AppMigrationError.self) {
            try AppMigrationCrypto.open(sealed, key: SymmetricKey(size: .bits256))
        }
        var tampered = sealed
        tampered[tampered.count - 1] ^= 0xFF
        #expect(throws: AppMigrationError.self) {
            try AppMigrationCrypto.open(tampered, key: session.key)
        }
    }

    @Test func handoffPhasesSurviveARelaunch() {
        defer { AppMigrationHandoffStore.save(nil) }
        let phases: [AppMigrationHandoffPhase] = [
            .requested(session, startedHere: true),
            .requested(session, startedHere: false),
            .handedOff(sessionID: session.id),
            .erased(sessionID: session.id),
        ]
        for phase in phases {
            AppMigrationHandoffStore.save(phase)
            #expect(AppMigrationHandoffStore.load() == phase)
            #expect(AppMigrationHandoffStore.isActive)
        }
        AppMigrationHandoffStore.save(nil)
        #expect(AppMigrationHandoffStore.load() == nil)
        #expect(!AppMigrationHandoffStore.isActive)
    }
}
