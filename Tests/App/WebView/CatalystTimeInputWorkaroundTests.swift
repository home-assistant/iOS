@testable import HomeAssistant
import Foundation
import Testing
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
}
