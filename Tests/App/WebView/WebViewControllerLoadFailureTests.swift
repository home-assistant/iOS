@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit
import WebKit

/// Load failures the web view reports that the URL error cases don't cover: WebKit's own errors,
/// errors from other domains, cancellations, and failures that follow a server error the controller
/// already turned into its empty state.
@MainActor
struct WebViewControllerLoadFailureTests {
    private func makeSUT() -> WebViewController {
        // A closed loopback port: a redirect to the server's root never reaches a real instance.
        let server = Server.fake { info in
            info.connection.set(address: URL(string: "http://127.0.0.1:9"), for: .external)
        }
        let sut = WebViewController(server: server)
        sut.isSceneActive = { _ in true }
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        // KVC-setting the view bypasses loadView/viewDidLoad, so nothing loads the server's URL.
        sut.setValue(containerView, forKey: "view")
        sut.webView = WKWebView(frame: containerView.bounds)
        sut.isAppInBackground = { false }
        return sut
    }

    @Test(arguments: [
        NSError(domain: "WebKitErrorDomain", code: 101),
        NSError(domain: "WebKitErrorDomain", code: 102),
        NSError(domain: "SomeOtherDomain", code: 7),
        NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError),
    ])
    func aFailedProvisionalLoadIsRecorded(error: NSError) {
        let sut = makeSUT()

        sut.webView(sut.webView, didFailProvisionalNavigation: nil, withError: error)

        // WebKit's "cannot show URL" sends the user back to the root instead of recording an error.
        if error.isCancelled || (error.domain == "WebKitErrorDomain" && error.code == 101) {
            #expect(sut.latestLoadError == nil)
        } else {
            #expect((sut.latestLoadError as NSError?)?.domain == error.domain)
        }
    }

    @Test func aFailureAfterAHandledServerErrorIsSwallowedOnce() {
        let sut = makeSUT()

        sut.didHandleServerErrorResponse = true
        sut.webView(sut.webView, didFailProvisionalNavigation: nil, withError: URLError(.timedOut))
        #expect(sut.latestLoadError == nil)
        #expect(!sut.didHandleServerErrorResponse)

        sut.didHandleServerErrorResponse = true
        sut.webView(sut.webView, didFail: nil, withError: URLError(.timedOut))
        #expect(sut.latestLoadError == nil)
        #expect(!sut.didHandleServerErrorResponse)
    }

    @Test func aCancelledNavigationIsNotAnError() {
        let sut = makeSUT()

        sut.webView(sut.webView, didFail: nil, withError: URLError(.cancelled))
        sut.webView(sut.webView, didFail: nil, withError: NSError(domain: "WebKitErrorDomain", code: 102))

        #expect(sut.latestLoadError == nil)
    }

    @Test func aFinishedLoadClearsTheLastError() {
        let sut = makeSUT()
        sut.latestLoadError = URLError(.timedOut)

        sut.webView(sut.webView, didFinish: nil)

        #expect(sut.latestLoadError == nil)
        #expect(sut.gestureRecognizer(
            UITapGestureRecognizer(),
            shouldRecognizeSimultaneouslyWith: UITapGestureRecognizer()
        ))
    }
}
