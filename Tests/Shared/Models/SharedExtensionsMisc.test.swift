import CoreLocation
import Foundation
import PromiseKit
@testable import Shared
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers
import XCGLogger

/// Small extensions in Shared/Common: activity indicators on image views, item provider loading,
/// Core Location error wording and hex colors.
struct SharedExtensionsMiscTests {
    private final class FakeExtensionContext: NSExtensionContext {
        var items: [Any] = []
        override var inputItems: [Any] { items }
    }

    @Test @MainActor func imageViewShowsAndHidesAnActivityIndicator() async {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        imageView.showActivityIndicator()
        imageView.showActivityIndicator()
        let deadline = Date().addingTimeInterval(10)
        while imageView.subviews.isEmpty, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let indicator = imageView.subviews.compactMap { $0 as? UIActivityIndicatorView }.first
        #expect(indicator != nil)
        #expect(imageView.subviews.count == 1)
        imageView.hideActivityIndicator()
        while indicator?.isAnimating == true, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(indicator?.isAnimating == false)
    }

    @Test func itemProvidersLoadTheRequestedType() async throws {
        let url = try #require(URL(string: "https://example.com/shared"))
        let urlProvider = NSItemProvider(item: url as NSURL, typeIdentifier: UTType.url.identifier)
        let loaded = try await urlProvider.item(for: .url).asyncValue()
        #expect(loaded == url)

        let textProvider = NSItemProvider(item: "hello" as NSString, typeIdentifier: UTType.text.identifier)
        let text = try await textProvider.item(for: .text).asyncValue()
        #expect(text == "hello")

        await #expect(throws: (any Error).self) {
            try await textProvider.item(for: .url).asyncValue()
        }
    }

    @Test func extensionContextsCollectEveryLoadableAttachment() async {
        let context = FakeExtensionContext()
        let item = NSExtensionItem()
        item.attachments = [
            NSItemProvider(item: "first" as NSString, typeIdentifier: UTType.text.identifier),
            NSItemProvider(item: URL(string: "https://example.com")! as NSURL, typeIdentifier: UTType.url.identifier),
            NSItemProvider(item: "second" as NSString, typeIdentifier: UTType.text.identifier),
        ]
        context.items = [item, "not an extension item"]
        let texts = await withCheckedContinuation { continuation in
            context.inputItemAttachments(for: .text).done { continuation.resume(returning: $0) }
        }
        #expect(texts.contains("first"))
        #expect(texts.contains("second"))
    }

    @Test func everyLocationErrorHasWording() {
        let codes: [CLError.Code] = [
            .locationUnknown, .denied, .network, .headingFailure, .regionMonitoringDenied,
            .regionMonitoringFailure, .regionMonitoringSetupDelayed, .regionMonitoringResponseDelayed,
            .geocodeFoundNoResult, .geocodeFoundPartialResult, .geocodeCanceled, .deferredFailed,
            .deferredNotUpdatingLocation, .deferredAccuracyTooLow, .deferredDistanceFiltered,
            .deferredCanceled, .rangingUnavailable, .rangingFailure, .promptDeclined,
        ]
        let descriptions = codes.map { CLError($0).debugDescription }
        #expect(descriptions.allSatisfy { !$0.isEmpty })
        #expect(Set(descriptions).count == codes.count)
    }

    @Test func hexColorsParseAndPrint() {
        #expect(Color(hex: "#3366CC").hex() == "3366CC")
        #expect(Color(hex: "33669980").hex() == "33669980")
        // Missing, unparsable and odd-length values all fall back to the app's primary color.
        #expect(Color(hex: nil).hex() != nil)
        #expect(Color(hex: "not-hex").hex() != nil)
        #expect(Color(hex: "12345").hex() != nil)
        #expect(Color.white.hex() == "FFFFFF")
        #expect(Color.black.opacity(0.5).hex() == "00000080")
    }

    @Test func notifyIsSilentWhileTesting() {
        Current.Log.notify("only in tests", log: .info)
        #expect(Current.isRunningTests)
        #expect(XCGLogger.notifyUserInfoKey != XCGLogger.shouldNotifyUserDefaultsKey)
    }
}
