import CoreNFC
import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

/// A tag written for an entity deep link has to survive the round trip: what the app puts on the tag is
/// what iOS hands back when the tag is scanned, and the app has to find the deep link inside it again.
struct NFCDeeplinkTagTests {
    @Test("A scanned deeplink tag opens the deeplink it was written with")
    func deeplinkTagRoundTripsThroughAScan() throws {
        let deeplink = try #require(AppConstants.openEntityMoreInfoDeeplinkURL(entityId: "light.kitchen"))
        let tagURL = try #require(AppConstants.nfcTagURL(deeplink: deeplink))

        // Background tag reading only routes the universal links the app claims, never the deep link itself.
        #expect(tagURL.absoluteString.hasPrefix("https://www.home-assistant.io/ios/nfc/?url="))

        guard case let .open(scanned) = TagActivityManager().handle(userActivity: activity(for: tagURL)) else {
            Issue.record("Expected a scanned deeplink tag to open its deeplink")
            return
        }

        #expect(scanned == deeplink)
    }

    @Test("A deeplink's own separators cannot leak into the tag URL")
    func deeplinkSeparatorsAreEscaped() throws {
        let deeplink = try #require(URL(string: "homeassistant://navigate/?more-info-entity-id=light.a&server=Home"))
        let tagURL = try #require(AppConstants.nfcTagURL(deeplink: deeplink))

        // An unescaped "&" or "?" would end the url value early and lose the rest of the deep link.
        let value = tagURL.absoluteString.replacingOccurrences(
            of: "https://www.home-assistant.io/ios/nfc/?url=",
            with: ""
        )
        #expect(!value.contains("&"))
        #expect(!value.contains("?"))

        guard case let .open(scanned) = TagActivityManager().handle(userActivity: activity(for: tagURL)) else {
            Issue.record("Expected a scanned deeplink tag to open its deeplink")
            return
        }

        #expect(scanned == deeplink)
    }

    @Test("The record written to a tag carries the deeplink's universal link")
    func writtenRecordCarriesTheTagURL() throws {
        let deeplink = try #require(AppConstants.openEntityMoreInfoDeeplinkURL(entityId: "light.kitchen"))
        let payload = try #require(iOSTagManager.deeplinkPayload(for: deeplink))

        let written = try #require(payload.wellKnownTypeURIPayload())
        #expect(written == AppConstants.nfcTagURL(deeplink: deeplink))

        // What was written is what a scan has to be able to turn back into the deeplink.
        guard case let .open(scanned) = TagActivityManager().handle(userActivity: activity(for: written)) else {
            Issue.record("Expected the written record to open its deeplink")
            return
        }

        #expect(scanned == deeplink)
    }

    #if targetEnvironment(simulator)
    @Test("The simulator reports a deeplink tag as written without any hardware")
    func simulatorWritesWithoutHardware() async throws {
        let deeplink = try #require(AppConstants.openEntityMoreInfoDeeplinkURL(entityId: "light.kitchen"))

        let error = await rejection(of: SimulatorTagManager().writeNFC(deeplink: deeplink, alertMessage: ""))

        #expect(error == nil)
    }
    #endif

    @Test("Writing a deeplink tag fails where NFC is unavailable")
    func writingFailsWithoutNFC() async throws {
        let deeplink = try #require(AppConstants.openEntityMoreInfoDeeplinkURL(entityId: "light.kitchen"))

        let onCatalyst = await rejection(of: TagActivityManager().writeNFC(deeplink: deeplink, alertMessage: ""))
        #expect(onCatalyst as? TagManagerError == .nfcUnavailable)

        let withoutNFC = await rejection(of: EmptyTagManager().writeNFC(deeplink: deeplink, alertMessage: ""))
        #expect(withoutNFC as? TagManagerError == .nfcUnavailable)
    }

    private func activity(for url: URL) -> NSUserActivity {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = url
        return activity
    }

    /// Why the promise was rejected, or `nil` if it was fulfilled. Waiting for it rather than blocking a
    /// thread on it keeps the test off the run loop the promise may itself need to settle.
    private func rejection(of promise: Promise<Void>) async -> (any Error)? {
        await withCheckedContinuation { (continuation: CheckedContinuation<(any Error)?, Never>) in
            promise.done {
                continuation.resume(returning: nil)
            }.catch { error in
                continuation.resume(returning: error)
            }
        }
    }
}
