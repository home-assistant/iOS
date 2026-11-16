import Foundation
@testable import HomeAssistant
import Testing
import UIKit
import WebKit

struct CatalystTimeInputWorkaroundTests {
    @Test @MainActor func userScriptRunsInEveryFrameBeforeThePageLoads() {
        let script = CatalystTimeInputWorkaround.userScript

        #expect(!script.isForMainFrameOnly)
        #expect(script.injectionTime == .atDocumentStart)
        #expect(script.source.contains("window.webkit.messageHandlers.\(CatalystTimeInputWorkaround.messageName)"))
    }

    @Test func minuteIntervalFollowsWholeMinuteSteps() {
        #expect(CatalystTimeInputOverlayView.minuteInterval(forStep: 60) == 1)
        #expect(CatalystTimeInputOverlayView.minuteInterval(forStep: 900) == 15)
        #expect(CatalystTimeInputOverlayView.minuteInterval(forStep: 30) == 1)
        #expect(CatalystTimeInputOverlayView.minuteInterval(forStep: 420) == 1)
        #expect(CatalystTimeInputOverlayView.minuteInterval(forStep: 3600) == 1)
    }

    @Test func parsesAndFormatsInputValues() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let date = try #require(CatalystTimeInputOverlayView.date(from: "07:45", calendar: calendar, now: now))
        #expect(calendar.component(.hour, from: date) == 7)
        #expect(calendar.component(.minute, from: date) == 45)
        #expect(CatalystTimeInputOverlayView.value(from: date, keepingSecondsOf: "", calendar: calendar) == "07:45")
        #expect(
            CatalystTimeInputOverlayView.value(from: date, keepingSecondsOf: "15:00:30", calendar: calendar)
                == "07:45:30"
        )
    }

    @Test func rejectsMalformedInputValues() {
        #expect(CatalystTimeInputOverlayView.date(from: "") == nil)
        #expect(CatalystTimeInputOverlayView.date(from: "24:00") == nil)
        #expect(CatalystTimeInputOverlayView.date(from: "ab:cd") == nil)
    }

    @Test func alignsTimeLikeTheInputsValue() {
        func alignment(_ textAlign: String, _ direction: String = "ltr") -> CatalystTimeInputOverlayView.Alignment {
            CatalystTimeInputMessageHandler.alignment(
                textAlign: textAlign,
                direction: direction,
                paddingLeft: 13,
                paddingRight: 7
            )
        }

        #expect(alignment("start") == .left(inset: 13))
        #expect(alignment("start", "rtl") == .right(inset: 7))
        #expect(alignment("center") == .center)
        #expect(alignment("-webkit-center") == .center)
        #expect(alignment("end") == .right(inset: 7))
        #expect(alignment("right", "rtl") == .right(inset: 7))
        #expect(alignment("") == .left(inset: 13))
    }

    @Test func readsAnchorRect() {
        let body: [String: Any] = ["rect": ["x": 10, "y": 20.5, "width": 100, "height": 30]]

        #expect(CatalystTimeInputMessageHandler.rect(from: body) == CGRect(x: 10, y: 20.5, width: 100, height: 30))
        #expect(CatalystTimeInputMessageHandler.rect(from: ["rect": ["x": 1]]) == nil)
    }

    @Test @MainActor func opensOverlayOverTheAnchoredInput() throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let handler = CatalystTimeInputMessageHandler(webViewProvider: { webView })

        handler.handleMessage(body: openBody(token: "a"), frame: nil, isMainFrame: false)
        #expect(overlays(in: webView).isEmpty)

        handler.handleMessage(body: anchorBody(token: "a"), frame: nil, isMainFrame: true)
        let overlay = try #require(overlays(in: webView).first)
        #expect(overlay.token == "a")
        #expect(overlay.frame.midX == 150)
        #expect(overlay.frame.midY == 215)
        #expect(overlay.layer.cornerRadius == 6)
    }

    @Test @MainActor func opensOverlayWhenAnchorArrivesFirst() {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let handler = CatalystTimeInputMessageHandler(webViewProvider: { webView })

        handler.handleMessage(body: anchorBody(token: "a"), frame: nil, isMainFrame: true)
        #expect(overlays(in: webView).isEmpty)

        handler.handleMessage(body: openBody(token: "a"), frame: nil, isMainFrame: false)
        #expect(overlays(in: webView).count == 1)
    }

    @Test @MainActor func ignoresAnchorsFromSubframesAndOtherInputs() {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let handler = CatalystTimeInputMessageHandler(webViewProvider: { webView })

        handler.handleMessage(body: openBody(token: "a"), frame: nil, isMainFrame: false)
        handler.handleMessage(body: anchorBody(token: "a"), frame: nil, isMainFrame: false)
        handler.handleMessage(body: anchorBody(token: "b"), frame: nil, isMainFrame: true)
        handler.handleMessage(body: ["kind": "anchor", "token": "a"], frame: nil, isMainFrame: true)

        #expect(overlays(in: webView).isEmpty)
    }

    @Test @MainActor func ignoresMalformedMessages() {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let handler = CatalystTimeInputMessageHandler(webViewProvider: { webView })

        handler.handleMessage(body: ["kind": "open"], frame: nil, isMainFrame: true)
        handler.handleMessage(body: ["kind": "unknown", "token": "a"], frame: nil, isMainFrame: true)

        #expect(overlays(in: webView).isEmpty)
    }

    @Test @MainActor func dismissOnlyRemovesTheMatchingOverlay() {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let handler = CatalystTimeInputMessageHandler(webViewProvider: { webView })
        handler.handleMessage(body: openBody(token: "a"), frame: nil, isMainFrame: false)
        handler.handleMessage(body: anchorBody(token: "a"), frame: nil, isMainFrame: true)

        handler.handleMessage(body: ["kind": "dismiss", "token": "b"], frame: nil, isMainFrame: false)
        #expect(overlays(in: webView).count == 1)

        handler.handleMessage(body: ["kind": "dismiss", "token": "a"], frame: nil, isMainFrame: false)
        #expect(overlays(in: webView).isEmpty)
    }

    @Test @MainActor func openingAnotherInputReplacesTheOverlay() {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let handler = CatalystTimeInputMessageHandler(webViewProvider: { webView })
        handler.handleMessage(body: openBody(token: "a"), frame: nil, isMainFrame: false)
        handler.handleMessage(body: anchorBody(token: "a"), frame: nil, isMainFrame: true)

        handler.handleMessage(body: openBody(token: "b"), frame: nil, isMainFrame: false)
        handler.handleMessage(body: anchorBody(token: "b"), frame: nil, isMainFrame: true)

        #expect(overlays(in: webView).map(\.token) == ["b"])
    }

    @Test @MainActor func scalesAnchorRectWithPageZoom() {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let rect = CGRect(x: 10, y: 20, width: 100, height: 30)

        #expect(CatalystTimeInputMessageHandler.scale(viewportWidth: 400, in: webView) == 2)
        #expect(CatalystTimeInputMessageHandler.scale(viewportWidth: nil, in: webView) == 1)
        #expect(CatalystTimeInputMessageHandler.scale(viewportWidth: 0, in: webView) == 1)
        #expect(
            CatalystTimeInputMessageHandler.webViewRect(for: rect, scale: 2, in: webView).size
                == CGSize(width: 200, height: 60)
        )
    }

    @Test @MainActor func overlayPositionsThePickerByAlignment() throws {
        let rect = CGRect(x: 100, y: 200, width: 600, height: 40)

        func pickerX(_ alignment: CatalystTimeInputOverlayView.Alignment) throws -> (CGFloat, CGFloat) {
            let overlay = CatalystTimeInputOverlayView(token: "a", value: "15:00", step: 60) { _ in }
            overlay.place(over: rect, cornerRadius: 4, alignment: alignment)
            let picker = try #require(overlay.subviews.first as? UIDatePicker)
            return (picker.frame.minX, overlay.bounds.width - picker.frame.width)
        }

        let (left, _) = try pickerX(.left(inset: 13))
        #expect(left == 13)
        let (center, centerSpace) = try pickerX(.center)
        #expect(center == centerSpace / 2)
        let (right, rightSpace) = try pickerX(.right(inset: 7))
        #expect(right == rightSpace - 7)
    }

    @Test @MainActor func overlayReportsPickedTimeKeepingSeconds() throws {
        var reported: String?
        let overlay = CatalystTimeInputOverlayView(token: "a", value: "15:00:30", step: 60) { reported = $0 }
        let picker = try #require(overlay.subviews.first as? UIDatePicker)
        #expect(picker.datePickerMode == .time)

        picker.date = try #require(CatalystTimeInputOverlayView.date(from: "07:45"))
        picker.sendActions(for: .valueChanged)

        #expect(reported == "07:45:30")
    }

    @Test @MainActor func pickingATimeKeepsTheOverlayOpen() throws {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let handler = CatalystTimeInputMessageHandler(webViewProvider: { webView })
        handler.handleMessage(body: openBody(token: "a"), frame: nil, isMainFrame: false)
        handler.handleMessage(body: anchorBody(token: "a"), frame: nil, isMainFrame: true)
        let overlay = try #require(overlays(in: webView).first)
        let picker = try #require(overlay.subviews.first as? UIDatePicker)

        picker.sendActions(for: .valueChanged)

        #expect(overlays(in: webView).count == 1)
    }

    @Test @MainActor func beginEditingIsSafeInAndOutOfAWindow() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let overlay = CatalystTimeInputOverlayView(token: "a", value: "15:00", step: 60) { _ in }
        window.addSubview(overlay)
        window.isHidden = false
        overlay.place(over: CGRect(x: 10, y: 10, width: 200, height: 40), cornerRadius: 4, alignment: .center)

        overlay.beginEditing(near: nil)
        overlay.beginEditing(near: CGPoint(x: 150, y: 20))
        try await Task.sleep(for: .milliseconds(400))
        overlay.removeFromSuperview()
        overlay.beginEditing(near: nil)
        try await Task.sleep(for: .milliseconds(50))
        window.isHidden = true
    }

    @MainActor private func overlays(in webView: WKWebView) -> [CatalystTimeInputOverlayView] {
        webView.subviews.compactMap { $0 as? CatalystTimeInputOverlayView }
    }

    private func openBody(token: String) -> [String: Any] {
        [
            "kind": "open",
            "token": token,
            "value": "15:00",
            "step": 60,
            "borderRadius": 3,
            "textAlign": "start",
            "direction": "ltr",
            "paddingLeft": 13,
            "paddingRight": 13,
            "clickX": 0.5,
        ]
    }

    private func anchorBody(token: String) -> [String: Any] {
        [
            "kind": "anchor",
            "token": token,
            "rect": ["x": 50, "y": 100, "width": 50, "height": 15],
            "viewportWidth": 400,
        ]
    }
}
