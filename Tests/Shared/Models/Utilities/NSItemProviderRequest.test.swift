import Foundation
import PromiseKit
@testable import Shared
import UniformTypeIdentifiers
import XCTest

final class NSItemProviderRequestTests: XCTestCase {
    private final class FakeExtensionContext: NSExtensionContext {
        var items: [Any] = []

        override var inputItems: [Any] {
            items
        }
    }

    private func urlProvider(_ string: String) -> NSItemProvider {
        NSItemProvider(item: URL(string: string)! as NSURL, typeIdentifier: UTType.url.identifier)
    }

    private func textProvider(_ text: String) -> NSItemProvider {
        NSItemProvider(item: text as NSString, typeIdentifier: UTType.text.identifier)
    }

    func testRequestTypeIdentifiers() {
        XCTAssertEqual(ItemProviderRequest<URL>.url.utType, UTType.url.identifier)
        XCTAssertEqual(ItemProviderRequest<String>.text.utType, UTType.text.identifier)
    }

    func testLoadsURL() throws {
        let url = try hang(urlProvider("https://example.com/path").item(for: ItemProviderRequest<URL>.url))
        XCTAssertEqual(url, URL(string: "https://example.com/path"))
    }

    func testLoadsText() throws {
        let text = try hang(textProvider("hello").item(for: ItemProviderRequest<String>.text))
        XCTAssertEqual(text, "hello")
    }

    func testMissingTypeRejects() {
        XCTAssertThrowsError(try hang(textProvider("hello").item(for: ItemProviderRequest<URL>.url)))
    }

    func testExtensionContextCollectsAttachmentsSkippingFailures() {
        let first = NSExtensionItem()
        first.attachments = [urlProvider("https://example.com/one"), textProvider("not a url")]
        let second = NSExtensionItem()
        second.attachments = [urlProvider("https://example.com/two")]
        let empty = NSExtensionItem()

        let context = FakeExtensionContext()
        context.items = [first, "not an extension item", second, empty]

        let loaded = expectation(description: "attachments loaded")
        var urls: [URL] = []
        context.inputItemAttachments(for: ItemProviderRequest<URL>.url).done {
            urls = $0
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 10)

        XCTAssertEqual(urls, [URL(string: "https://example.com/one")!, URL(string: "https://example.com/two")!])
    }
}
