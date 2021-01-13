import Foundation
@testable import Shared
import XCTest
import PromiseKit
import OHHTTPStubs
import CoreServices

class NotificationAttachmentManagerTests: XCTestCase {
    private var manager: NotificationAttachmentManager!
    private var api: FakeHomeAssistantAPI!
    private var parser1: FakeNotificationParser1.Type!
    private var parser2: FakeNotificationParser2.Type!
    private var parser3: FakeNotificationParser3.Type!

    private var image1: Image!
    private var image2: Image!

    override func setUp() {
        super.setUp()

        Current.settingsStore.connectionInfo = .init(
            externalURL: URL(string: "http://example.com")!,
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhookid",
            webhookSecret: "webhooksecret",
            internalSSIDs: nil,
            internalHardwareAddresses: nil
        )

        image1 = .init()
        image2 = .init()

        api = FakeHomeAssistantAPI(
            tokenInfo: .init(
                accessToken: "atoken",
                refreshToken: "refreshtoken",
                expiration: Date(timeIntervalSinceNow: 10000)
            )
        )

        parser1 = FakeNotificationParser1.self
        parser1.reset()

        parser2 = FakeNotificationParser2.self
        parser2.reset()

        parser3 = FakeNotificationParser3.self
        parser3.reset()

        manager = NotificationAttachmentManager(parsers: [parser1, parser2, parser3])
    }

    private func firstAttachment(for content: UNNotificationContent) throws -> UNNotificationAttachment {
        let promise = manager.content(from: content, api: api)
        let content = try hang(Promise(promise))
        if let attachment =  content.attachments.first {
            return attachment
        } else {
            enum NoAttachmentError: Error { case noAttachment }
            throw NoAttachmentError.noAttachment
        }
    }

    func testDefaultParsers() {
        let parsers = NotificationAttachmentManager().parsers
        XCTAssertFalse(parsers.isEmpty)
    }

    func testSummaryArgumentAlreadySet() throws {
        let content = with(UNMutableNotificationContent()) {
            $0.summaryArgument = "things"
            $0.threadIdentifier = "thread_identifier"
            $0.categoryIdentifier = "category_identifier"
        }
        let promise = manager.content(from: content, api: api)
        let result = try hang(Promise(promise))
        XCTAssertEqual(result.summaryArgument, "things")
    }

    func testSummaryArgumentArgumentFromThreadIdentifier() throws {
        let content = with(UNMutableNotificationContent()) {
            $0.summaryArgument = ""
            $0.threadIdentifier = "thread_identifier"
            $0.categoryIdentifier = "category_identifier"
        }
        let promise = manager.content(from: content, api: api)
        let result = try hang(Promise(promise))
        XCTAssertEqual(result.summaryArgument, "thread_identifier")
    }

    func testSummaryArgumentArgumentFromCategoryIdentifier() throws {
        let content = with(UNMutableNotificationContent()) {
            $0.summaryArgument = ""
            $0.threadIdentifier = ""
            $0.categoryIdentifier = "category_identifier"
        }
        let promise = manager.content(from: content, api: api)
        let result = try hang(Promise(promise))
        XCTAssertEqual(result.summaryArgument, "category_identifier")
    }

    func testAllMissing() {
        parser1.result = .missing
        parser2.result = .missing
        parser3.result = .missing

        let content = UNNotificationContent()
        let promise = manager.content(from: content, api: api)
        XCTAssertEqual(try hang(Promise(promise)), content)
    }

    func testOneContentUnauth() throws {
        parser2.result = image1.successParserResult(needsAuth: false)

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(try Data(contentsOf: attachment.url), image1.data)
    }

    func testOneContentAuth() throws {
        parser2.result = image1.successParserResult(needsAuth: true)

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(try Data(contentsOf: attachment.url), image1.data)
    }

    func testTwoContentUnauth() throws {
        parser1.result = image1.successParserResult(needsAuth: false)
        parser2.result = image2.successParserResult(needsAuth: false)

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(try Data(contentsOf: attachment.url), image1.data)
    }

    func testTwoContentAuth() throws {
        parser1.result = image1.successParserResult(needsAuth: false)
        parser2.result = image2.successParserResult(needsAuth: true)

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(try Data(contentsOf: attachment.url), image1.data)
    }

    func testContentTimesOut() throws {
        let error = URLError(.timedOut)
        parser1.result = image1.failureParserResult(failure: .error(error))

        let attachment = try firstAttachment(for: .init())
        XCTAssertNotEqual(try Data(contentsOf: attachment.url), image1.data)
        XCTAssertTrue(attachment.accessibilityLabel?.contains(error.localizedDescription) == true)
    }

    func testContentNotFound() throws {
        parser1.result = image1.failureParserResult(failure: .statusCode(404))

        let attachment = try firstAttachment(for: .init())
        XCTAssertNotEqual(try Data(contentsOf: attachment.url), image1.data)
        XCTAssertTrue(attachment.accessibilityLabel?.contains("404") == true)
    }

    func testContentType() throws {
        parser1.result = image1.successParserResult(
            needsAuth: false,
            typeHint: kUTTypeGIF,
            hideThumbnail: nil
        )

        let attachment = try firstAttachment(for: .init())
        XCTAssertEqual(attachment.type, kUTTypeGIF as String)
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
    }
}

private class Image {
    var image: UIImage
    var data: Data
    private var stubDescriptors: [HTTPStubsDescriptor] = []

    private class func newURL() -> URL {
        return URL(string: "http://example.com/" + UUID().uuidString + ".png")!
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
        hideThumbnail: Bool? = nil
    ) -> NotificationAttachmentParserResult {
        let url = Self.newURL()

        stubDescriptors.append(stub(condition: { $0.url == url }, response: { [data] request in
            if needsAuth {
                if request.allHTTPHeaderFields?["Authorization"] == "Bearer atoken" {
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
            hideThumbnail: hideThumbnail
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

        stubDescriptors.append(stub(condition: { $0.url == url }, response: { request in
            switch failure {
            case .error(let error):
                return .init(error: error)
            case .statusCode(let statusCode):
                return .init(data: Data(), statusCode: statusCode, headers: [:])
            }
        }))

        return .fulfilled(.init(
            url: url,
            needsAuth: needsAuth,
            typeHint: nil,
            hideThumbnail: nil
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
        return .value(Self.result)
    }
}

private class FakeNotificationParser2: NotificationAttachmentParser {
    required init() {}

    static func reset() {
        result = .rejected(UnSetError.unset)
    }
    static var result: NotificationAttachmentParserResult = .rejected(UnSetError.unset)

    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult> {
        return .value(Self.result)
    }
}

private class FakeNotificationParser3: NotificationAttachmentParser {
    required init() {}

    static func reset() {
        result = .rejected(UnSetError.unset)
    }
    static var result: NotificationAttachmentParserResult = .rejected(UnSetError.unset)

    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult> {
        return .value(Self.result)
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {

}
