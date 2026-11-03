@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit
import UIKit.UIGestureRecognizerSubclass
import WebKit

/// Pull to refresh on the frontend's scroll view: how far a pull has got, the refresh it starts once
/// it is let go past the threshold, and how it settles again. Pulls are made by moving the scroll
/// view's offset and ending the pan the way the gesture system would.
@MainActor
struct HomeAssistantPullToRefreshObserverTests {
    private final class Recorder {
        var states: [(progress: CGFloat, isRefreshing: Bool)] = []
        var refreshes = 0
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func makeSUT() -> (HomeAssistantPullToRefreshObserver, WKWebView, Recorder) {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        webView.scrollView.contentSize = CGSize(width: 390, height: 2000)
        let recorder = Recorder()
        let sut = HomeAssistantPullToRefreshObserver(
            webView: webView,
            maximumThreshold: 120,
            onStateChange: { recorder.states.append(($0, $1)) },
            onRefresh: { recorder.refreshes += 1 }
        )
        return (sut, webView, recorder)
    }

    /// A pan whose state is whatever the test says, since a real one only changes state while
    /// touches are being delivered.
    private final class ScriptedPan: UIPanGestureRecognizer {
        var scriptedState: UIGestureRecognizer.State = .possible

        override var state: UIGestureRecognizer.State {
            get { scriptedState }
            set { scriptedState = newValue }
        }
    }

    private func endPan(_ state: UIGestureRecognizer.State, on sut: HomeAssistantPullToRefreshObserver) {
        let recognizer = ScriptedPan()
        recognizer.scriptedState = state
        sut.perform(NSSelectorFromString("handlePanGesture:"), with: recognizer)
    }

    @Test func aPullPastTheThresholdRefreshesOnceLetGo() async {
        let (sut, webView, recorder) = makeSUT()

        for offset in stride(from: -20, through: -200, by: -20) {
            webView.scrollView.contentOffset = CGPoint(x: 0, y: offset)
        }
        let expectation1 = await waitUntil { recorder.states.contains { $0.progress >= 1 } }
        #expect(expectation1)

        endPan(.ended, on: sut)
        #expect(recorder.refreshes == 1)
        #expect(recorder.states.last?.isRefreshing == true)

        // A second release while refreshing starts nothing new.
        endPan(.ended, on: sut)
        #expect(recorder.refreshes == 1)

        sut.finishRefreshing()
        #expect(recorder.states.last?.isRefreshing == false)
        #expect(recorder.states.last?.progress == 0)
        // Finishing twice reports nothing more.
        let count = recorder.states.count
        sut.finishRefreshing()
        #expect(recorder.states.count == count)
    }

    @Test func aShortPullDoesNotRefresh() async {
        let (sut, webView, recorder) = makeSUT()

        webView.scrollView.contentOffset = CGPoint(x: 0, y: -30)
        let expectation2 = await waitUntil { recorder.states.contains { $0.progress > 0 } }
        #expect(expectation2)
        endPan(.ended, on: sut)
        endPan(.cancelled, on: sut)
        endPan(.changed, on: sut)

        webView.scrollView.contentOffset = .zero
        let expectation3 = await waitUntil { recorder.states.last?.progress == 0 }
        #expect(expectation3)
        #expect(recorder.refreshes == 0)
    }

    @Test(arguments: [0.0, 0.4, 1.0])
    func rendersTheIndicator(progress: Double) {
        for isRefreshing in [false, true] {
            let controller = UIHostingController(rootView: HomeAssistantPullToRefreshView(
                progress: progress,
                isRefreshing: isRefreshing
            ))
            controller.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
            controller.view.layoutIfNeeded()
        }
    }
}
