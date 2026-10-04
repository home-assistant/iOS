#if !targetEnvironment(macCatalyst)
import CoreNFC
#endif
import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

/// What the tag manager does with the links that reach it, and how it refuses NFC work on a device
/// that has none.
struct TagActivityManagerTests {
    @Test func reportsNoNFCAndRefusesEveryTagOperation() {
        let manager = TagActivityManager()

        #expect(manager.isNFCAvailable == false)
        #expect(manager.readNFC().error as? TagManagerError == .nfcUnavailable)
        #expect(manager.writeNFC(value: "tag").error as? TagManagerError == .nfcUnavailable)
        #expect(
            manager.writeNFC(deeplink: URL(string: "homeassistant://navigate/lovelace")!, alertMessage: "Hold")
                .error as? TagManagerError == .nfcUnavailable
        )
    }

    @Test func anActivityWithoutALinkIsUnhandled() {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)

        guard case .unhandled = TagActivityManager().handle(userActivity: activity) else {
            Issue.record("Expected an activity without a link to be unhandled")
            return
        }
    }

    @Test func aLinkCarryingAURLOpensIt() throws {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity
            .webpageURL = URL(string: "https://my.home-assistant.io/redirect/nfc/?url=homeassistant://navigate/energy")

        guard case let .open(url) = TagActivityManager().handle(userActivity: activity) else {
            Issue.record("Expected the link's url to be opened")
            return
        }
        #expect(url.absoluteString == "homeassistant://navigate/energy")
    }

    @Test func linksThatAreNotTagsAreUnhandled() {
        let urls = [
            "https://www.home-assistant.io/tag/",
            "https://www.home-assistant.io/blog/some-post",
            "https://example.com/tag/abc",
        ]
        for string in urls {
            let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            activity.webpageURL = URL(string: string)
            guard case .unhandled = TagActivityManager().handle(userActivity: activity) else {
                Issue.record("Expected \(string) to be unhandled")
                continue
            }
        }
    }

    @Test func handledTypeIsGenericWithoutAnNFCPayload() {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        #expect(TagActivityManager().handledType(from: activity) == .generic)
    }

    #if !targetEnvironment(macCatalyst)
    @Test func androidPackageRecordIsAnExternalRecordNamingThePackage() throws {
        let payload = try #require(NFCNDEFPayload.androidPackage(payload: "io.homeassistant.companion.android"))

        #expect(payload.typeNameFormat == .nfcExternal)
        #expect(payload.type == Data("android.com:pkg".utf8))
        #expect(payload.identifier.isEmpty)
        #expect(payload.payload == Data("io.homeassistant.companion.android".utf8))
    }
    #endif
}
