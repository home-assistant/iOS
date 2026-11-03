import CoreNFC
import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// What a tag manager does without NFC hardware: universal links it does and does not handle, and
/// the records it would write.
@Suite
struct TagActivityManagerTests {
    private func activity(_ url: String?) -> NSUserActivity {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = url.flatMap(URL.init(string:))
        return activity
    }

    @Test func handlesOnlyHomeAssistantTagLinksAndURLRedirects() {
        let manager = TagActivityManager()
        if case .unhandled = manager.handle(userActivity: activity(nil)) {} else {
            Issue.record("an activity without a URL is not a tag")
        }
        if case .unhandled = manager.handle(userActivity: activity("https://example.com/tag/abc")) {} else {
            Issue.record("another host is not a tag")
        }
        if case .unhandled = manager.handle(userActivity: activity("https://www.home-assistant.io/tag/")) {} else {
            Issue.record("an empty tag is not a tag")
        }
        if case .unhandled = manager.handle(userActivity: activity("https://www.home-assistant.io/blog")) {} else {
            Issue.record("another page is not a tag")
        }
        if case let .open(url) = manager.handle(
            userActivity: activity("https://www.home-assistant.io/nfc?url=homeassistant://navigate/lovelace")
        ) {
            #expect(url.scheme == "homeassistant")
        } else {
            Issue.record("a url parameter opens that URL")
        }
        #expect(manager.handledType(from: activity(nil)) == .generic)
    }

    @Test func withoutHardwareNothingIsReadOrWritten() async {
        let manager = TagActivityManager()
        #expect(!manager.isNFCAvailable)
        await #expect(throws: (any Error).self) { try await manager.readNFC().async() }
        await #expect(throws: (any Error).self) { try await manager.writeNFC(value: "x").async() }
        await #expect(throws: (any Error).self) {
            try await manager.writeNFC(deeplink: URL(string: "homeassistant://x")!, alertMessage: "").async()
        }
    }

    @Test func androidPackageRecordNamesTheCompanionApp() throws {
        let payload = try #require(NFCNDEFPayload.androidPackage(payload: "io.homeassistant.companion.android"))
        #expect(payload.typeNameFormat == .nfcExternal)
        #expect(String(data: payload.type, encoding: .ascii) == "android.com:pkg")
        #expect(String(data: payload.payload, encoding: .utf8) == "io.homeassistant.companion.android")
    }

    @Test func errorsDescribeThemselves() {
        for error in [TagManagerError.nfcUnavailable, .notHomeAssistantTag, .invalidURL] {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}
