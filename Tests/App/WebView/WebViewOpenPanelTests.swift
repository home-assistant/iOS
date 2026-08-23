@testable import HomeAssistant
import UniformTypeIdentifiers
import XCTest

final class WebViewOpenPanelTests: XCTestCase {
    func testEmptyRequestedTypesAllowAudioItemAndFlac() {
        let types = WebViewOpenPanelContentTypes.contentTypes(requested: [])

        XCTAssertEqual(types, WebViewOpenPanelContentTypes.audioFallbackTypes)
        XCTAssertTrue(types.contains(.audio))
        XCTAssertTrue(types.contains(.item))
        XCTAssertTrue(types.contains(.flac))
    }

    func testAudioSupertypeIsLeftAloneBecauseFlacConformsToIt() {
        let types = WebViewOpenPanelContentTypes.contentTypes(requested: [.audio])

        XCTAssertEqual(types, [.audio])
        XCTAssertTrue(WebViewOpenPanelContentTypes.allowsSelectingFlac(types))
    }

    func testNarrowAudioListIsWidenedToIncludeFlac() {
        let types = WebViewOpenPanelContentTypes.contentTypes(requested: [.mp3])

        XCTAssertTrue(types.contains(.mp3))
        XCTAssertTrue(types.contains(.audio))
        XCTAssertTrue(types.contains(.item))
        XCTAssertTrue(types.contains(.flac))
        XCTAssertTrue(WebViewOpenPanelContentTypes.allowsSelectingFlac(types))
    }

    func testImageOnlyListsAreNotWidened() {
        let types = WebViewOpenPanelContentTypes.contentTypes(requested: [.jpeg, .png])

        XCTAssertEqual(types, [.jpeg, .png])
        XCTAssertFalse(types.contains(.flac))
    }

    func testRequestedTypesReadsAllowedContentTypesWhenPresent() {
        let parameters = FakeOpenPanelParameters(allowedContentTypes: [.mp3, .wav])

        let types = WebViewOpenPanelContentTypes.requestedTypes(from: parameters)

        XCTAssertEqual(types, [.mp3, .wav])
    }

    func testRequestedTypesReturnsEmptyWhenPropertyIsMissing() {
        let types = WebViewOpenPanelContentTypes.requestedTypes(from: NSObject())

        XCTAssertEqual(types, [])
    }

    func testAudioRelatedDetection() {
        XCTAssertTrue(WebViewOpenPanelContentTypes.isAudioRelated([.mp3]))
        XCTAssertTrue(WebViewOpenPanelContentTypes.isAudioRelated([.audio]))
        XCTAssertFalse(WebViewOpenPanelContentTypes.isAudioRelated([.jpeg]))
    }
}

private final class FakeOpenPanelParameters: NSObject {
    @objc let allowedContentTypes: [UTType]

    init(allowedContentTypes: [UTType]) {
        self.allowedContentTypes = allowedContentTypes
    }
}
