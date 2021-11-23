import Alamofire
import CoreServices
import Foundation
import OHHTTPStubs
import PromiseKit
@testable import Shared
import XCTest

class NotificationAttachmentManagerTests: XCTestCase {
    private var manager: NotificationAttachmentManagerImpl!
    private var api: FakeHomeAssistantAPI!
    private var parser1: FakeNotificationParser1.Type!
    private var parser2: FakeNotificationParser2.Type!
    private var parser3: FakeNotificationParser3.Type!

    private var image1: Image!
    private var image2: Image!

    override func setUp() {
        super.setUp()

        image1 = .init()
        image2 = .init()

        api = FakeHomeAssistantAPI(server: .fake())

        parser1 = FakeNotificationParser1.self
        parser1.reset()

        parser2 = FakeNotificationParser2.self
        parser2.reset()

        parser3 = FakeNotificationParser3.self
        parser3.reset()

        manager = NotificationAttachmentManagerImpl(parsers: [parser1, parser2, parser3])
    }

    private func firstAttachment(for content: UNNotificationContent) throws -> UNNotificationAttachment {
        let promise = manager.content(from: content, api: api)
        let content = try hang(Promise(promise))
        if let attachment = content.attachments.first {
            return attachment
        } else {
            enum NoAttachmentError: Error { case noAttachment }
            throw NoAttachmentError.noAttachment
        }
    }

    private func assertDownloadedAttachment(for content: UNNotificationContent, api: HomeAssistantAPI) throws {
        let promise = manager.downloadAttachment(from: content, api: api)
        let url = try hang(Promise(promise))
        if UIImage(contentsOfFile: url.path) == nil {
            enum NoImageError: Error { case noImage }
            throw NoImageError.noImage
        }
    }

    func testDefaultParsers() {
        let parsers = NotificationAttachmentManagerImpl().parsers
        XCTAssertFalse(parsers.isEmpty)
    }

    func testAllMissing() {
        parser1.result = .missing
        parser2.result = .missing
        parser3.result = .missing

        let content = UNNotificationContent()
        let promise = manager.content(from: content, api: api)
        XCTAssertEqual(try hang(Promise(promise)), content)
        XCTAssertThrowsError(try hang(Promise(manager.downloadAttachment(from: content, api: api))))
    }

    func testOneContentUnauth() throws {
        parser2.result = image1.successParserResult(needsAuth: false)

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(try Data(contentsOf: attachment.url), image1.data)
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testOneContentAuth() throws {
        parser2.result = image1.successParserResult(needsAuth: true)

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(try Data(contentsOf: attachment.url), image1.data)
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testTwoContentUnauth() throws {
        parser1.result = image1.successParserResult(needsAuth: false)
        parser2.result = image2.successParserResult(needsAuth: false)

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(try Data(contentsOf: attachment.url), image1.data)
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testTwoContentAuth() throws {
        parser1.result = image1.successParserResult(needsAuth: false)
        parser2.result = image2.successParserResult(needsAuth: true)

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(try Data(contentsOf: attachment.url), image1.data)
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testContentTimesOut() throws {
        let error = URLError(.timedOut)
        parser1.result = image1.failureParserResult(failure: .error(error))

        // no attachment to notification
        XCTAssertThrowsError(try firstAttachment(for: .init()))
        // but error image when downloading
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testContentDownloadErrors() throws {
        let error = AFError.sessionTaskFailed(error: URLError(.timedOut))
        parser1.result = image1.failureParserResult(failure: .error(error))

        // no attachment to notification
        XCTAssertThrowsError(try firstAttachment(for: .init()))
        // but error image when downloading
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testContentNotFound() throws {
        parser1.result = image1.failureParserResult(failure: .statusCode(404))

        let attachment = try firstAttachment(for: .init())
        XCTAssertNotEqual(try Data(contentsOf: attachment.url), image1.data)
        XCTAssertTrue(attachment.accessibilityLabel?.contains("404") == true)
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testContentType() throws {
        parser1.result = image1.successParserResult(
            needsAuth: false,
            typeHint: kUTTypeGIF,
            hideThumbnail: nil
        )

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(attachment.type, kUTTypeGIF as String)
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testHideThumbnailDefault() throws {
        parser1.result = image1.successParserResult(
            needsAuth: false,
            typeHint: nil,
            hideThumbnail: nil
        )

        let attachment = try firstAttachment(for: .init())
        // fragile? yes. lazy? yes. effective? ask me in an iOS release
        XCTAssertTrue(attachment.debugDescription.contains("displayLocation: default"))
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testHideThumbnailTrue() throws {
        parser1.result = image1.successParserResult(
            needsAuth: false,
            typeHint: nil,
            hideThumbnail: true
        )

        let attachment = try firstAttachment(for: .init())
        // fragile? yes. lazy? yes. effective? ask me in an iOS release
        XCTAssertTrue(attachment.debugDescription.contains("displayLocation: long-look"))
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testHideThumbnailFalse() throws {
        parser1.result = image1.successParserResult(
            needsAuth: false,
            typeHint: nil,
            hideThumbnail: false
        )

        let attachment = try firstAttachment(for: .init())
        // fragile? yes. lazy? yes. effective? ask me in an iOS release
        XCTAssertTrue(attachment.debugDescription.contains("displayLocation: default"))
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }

    func testLazy() throws {
        parser1.result = image1.successParserResult(
            needsAuth: false,
            typeHint: nil,
            hideThumbnail: nil,
            lazy: true
        )

        let content = UNNotificationContent()
        let promise = manager.content(from: content, api: api)
        XCTAssertEqual(try hang(Promise(promise)), content)
        XCTAssertNoThrow(try assertDownloadedAttachment(for: .init(), api: api))
    }
}

private class Image {
    var image: UIImage
    var data: Data
    private var stubDescriptors: [HTTPStubsDescriptor] = []

    private class func newURL() -> URL {
        URL(string: "http://homeassistant.local:8123/" + UUID().uuidString + ".png")!
    }

    init() {
        let size = CGSize(width: 10, height: 10)
        let data = UIGraphicsImageRenderer(size: size).pngData { _ in
            UIColor.randomBackgroundColor().setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
        }

        self.data = data
        self.image = UIImage(data: data)!
    }

    deinit {
        for descriptor in stubDescriptors {
            HTTPStubs.removeStub(descriptor)
        }
    }

    func successParserResult(
        needsAuth: Bool = false,
        typeHint: CFString? = nil,
        hideThumbnail: Bool? = nil,
        lazy: Bool = false
    ) -> NotificationAttachmentParserResult {
        let url = Self.newURL()

        stubDescriptors.append(stub(condition: { $0.url == url }, response: { [data] request in
            if needsAuth {
                if request.allHTTPHeaderFields?["Authorization"] == "Bearer FakeAccessToken" {
                    return .init(data: data, statusCode: 200, headers: [:])
                } else {
                    return .init(data: Data(), statusCode: 401, headers: [:])
                }
            } else {
                if request.allHTTPHeaderFields?["Authorization"] == nil {
                    return .init(data: data, statusCode: 200, headers: [:])
                } else {
                    return .init(data: Data(), statusCode: 401, headers: [:])
                }
            }
        }))

        return .fulfilled(.init(
            url: url,
            needsAuth: needsAuth,
            typeHint: typeHint,
            hideThumbnail: hideThumbnail,
            lazy: lazy
        ))
    }

    enum FailureType {
        case error(Error)
        case statusCode(Int32)
    }

    func failureParserResult(
        failure: FailureType,
        needsAuth: Bool = false
    ) -> NotificationAttachmentParserResult {
        let url = Self.newURL()

        stubDescriptors.append(stub(condition: { $0.url == url }, response: { _ in
            switch failure {
            case let .error(error):
                return .init(error: error)
            case let .statusCode(statusCode):
                return .init(data: Data(), statusCode: statusCode, headers: [:])
            }
        }))

        return .fulfilled(.init(
            url: url,
            needsAuth: needsAuth,
            typeHint: nil,
            hideThumbnail: nil,
            lazy: false
        ))
    }
}

private enum UnSetError: Error {
    case unset
}

private class FakeNotificationParser1: NotificationAttachmentParser {
    required init() {}

    static func reset() {
        result = .rejected(UnSetError.unset)
    }

    static var result: NotificationAttachmentParserResult = .rejected(UnSetError.unset)

    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult> {
        .value(Self.result)
    }
}

private class FakeNotificationParser2: NotificationAttachmentParser {
    required init() {}

    static func reset() {
        result = .rejected(UnSetError.unset)
    }

    static var result: NotificationAttachmentParserResult = .rejected(UnSetError.unset)

    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult> {
        .value(Self.result)
    }
}

private class FakeNotificationParser3: NotificationAttachmentParser {
    required init() {}

    static func reset() {
        result = .rejected(UnSetError.unset)
    }

    static var result: NotificationAttachmentParserResult = .rejected(UnSetError.unset)

    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult> {
        .value(Self.result)
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {}
