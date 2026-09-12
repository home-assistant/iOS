@testable import HomeAssistant
import PromiseKit
import Shared
import XCTest

@MainActor
final class EntityAddToHandlerTests: XCTestCase {
    private var originalTags: TagManager!
    private var tags: MockTagManager!

    override func setUp() {
        super.setUp()
        originalTags = Current.tags
        tags = MockTagManager()
        Current.tags = tags
    }

    override func tearDown() {
        Current.tags = originalTags
        super.tearDown()
    }

    func testDeeplinkActionPresentsTheDeeplinkSheetForTheEntity() throws {
        let webView = MockWebViewController()
        let sut = EntityAddToHandler(webViewController: webView)
        let executed = expectation(description: "deeplink action executed")

        sut.execute(action: DeeplinkAction(), entityId: "light.kitchen").done {
            executed.fulfill()
        }.cauterize()
        wait(for: [executed], timeout: 10.0)

        XCTAssertTrue(webView.presentOverlayControllerCalled)
        let controller = try XCTUnwrap(webView.overlayedController)
        XCTAssertTrue(String(describing: type(of: controller)).contains("DeeplinkView"))
    }

    func testNFCTagActionWritesTheEntityDeeplinkToATag() throws {
        let webView = MockWebViewController()
        let sut = EntityAddToHandler(webViewController: webView)
        let executed = expectation(description: "nfc tag action executed")

        sut.execute(action: NFCTagAction(), entityId: "light.kitchen").done {
            executed.fulfill()
        }.cauterize()
        wait(for: [executed], timeout: 10.0)

        let expectedURL = try XCTUnwrap(DeeplinkTarget.entity(id: "light.kitchen").url(serverName: nil))
        XCTAssertEqual(tags.writtenURLs, [expectedURL])
        XCTAssertEqual(
            tags.writeURLAlertMessages,
            [L10n.Nfc.Write.Deeplink.startMessage(Current.device.inspecificModel())]
        )
        // The system NFC sheet is the whole interaction, so nothing of ours is presented on top of it.
        XCTAssertFalse(webView.presentOverlayControllerCalled)
    }

    func testNFCTagActionFailsWhenTheTagCannotBeWritten() {
        tags.writeURLResult = .init(error: TagManagerError.invalidURL)
        let sut = EntityAddToHandler(webViewController: MockWebViewController())
        let failed = expectation(description: "nfc tag action failed")

        sut.execute(action: NFCTagAction(), entityId: "light.kitchen").catch { error in
            XCTAssertEqual(error as? TagManagerError, .invalidURL)
            failed.fulfill()
        }
        wait(for: [failed], timeout: 10.0)
    }

    func testActionsForEntityIncludesNFCTagActionWhenNFCIsAvailable() {
        tags.isNFCAvailable = true
        let sut = EntityAddToHandler(webViewController: MockWebViewController())
        let resolved = expectation(description: "actions resolved")

        sut.actionsForEntity(entityId: "light.kitchen").done { actions in
            XCTAssertTrue(actions.contains { $0.actionType == EntityAddToActionType.nfcTag.rawValue })
            resolved.fulfill()
        }.cauterize()
        wait(for: [resolved], timeout: 10.0)
    }

    func testActionsForEntityOmitsNFCTagActionWhenNFCIsUnavailable() {
        tags.isNFCAvailable = false
        let sut = EntityAddToHandler(webViewController: MockWebViewController())
        let resolved = expectation(description: "actions resolved")

        sut.actionsForEntity(entityId: "light.kitchen").done { actions in
            XCTAssertFalse(actions.contains { $0.actionType == EntityAddToActionType.nfcTag.rawValue })
            XCTAssertTrue(actions.contains { $0.actionType == EntityAddToActionType.deeplink.rawValue })
            resolved.fulfill()
        }.cauterize()
        wait(for: [resolved], timeout: 10.0)
    }

    func testActionsForEntityOmitsBothLinkActionsForAnUnknownDomain() {
        let sut = EntityAddToHandler(webViewController: MockWebViewController())
        let resolved = expectation(description: "actions resolved")

        sut.actionsForEntity(entityId: "not_a_domain.kitchen").done { actions in
            XCTAssertFalse(actions.contains { $0.actionType == EntityAddToActionType.nfcTag.rawValue })
            XCTAssertFalse(actions.contains { $0.actionType == EntityAddToActionType.deeplink.rawValue })
            resolved.fulfill()
        }.cauterize()
        wait(for: [resolved], timeout: 10.0)
    }

    func testNFCTagActionSurvivesTheRoundTripThroughTheFrontend() throws {
        let external = try ExternalEntityAddToAction.from(action: NFCTagAction())

        XCTAssertEqual(external.name, L10n.WebView.AddTo.Option.NfcTag.title)
        XCTAssertEqual(external.mdiIcon, "mdi:nfc-variant")
        XCTAssertTrue(external.enabled)

        let decoded = try ExternalEntityAddToAction.toAction(from: external.appPayload)
        XCTAssertEqual(decoded.actionType, EntityAddToActionType.nfcTag.rawValue)
        XCTAssertTrue(decoded is NFCTagAction)
    }
}
