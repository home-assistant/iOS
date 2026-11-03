@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The empty state's button stack for every style: what the primary button runs, the recovered
/// server's reported re-authentication, and each layout (URL picker, error details, settings).
@MainActor
struct WebViewEmptyStateActionButtonsStylesTests {
    private enum ReauthError: Error {
        case failed
    }

    private final class Recorder {
        var retries = 0
        var reauthenticated: [ConnectionInfo.URLType] = []
        var recovered: [ConnectionInfo.URLType] = []
    }

    private func makeSUT(
        style: WebViewEmptyStateStyle,
        urlTypes: [ConnectionInfo.URLType] = [.internal, .external],
        showsErrorDetailsButton: Bool = false,
        recorder: Recorder,
        recoveredOutcome: Swift.Result<Void, Error>? = nil
    ) -> WebViewEmptyStateActionButtons {
        typealias RecoveredAction = (ConnectionInfo.URLType, @escaping (Swift.Result<Void, Error>) -> Void) -> Void
        var recoveredAction: RecoveredAction?
        if let recoveredOutcome {
            recoveredAction = { urlType, completion in
                recorder.recovered.append(urlType)
                completion(recoveredOutcome)
            }
        }
        return WebViewEmptyStateActionButtons(
            style: style,
            availableReauthURLTypes: urlTypes,
            showsErrorDetailsButton: showsErrorDetailsButton,
            retryAction: { recorder.retries += 1 },
            settingsAction: {},
            errorDetailsAction: {},
            reauthAction: { recorder.reauthenticated.append($0) },
            recoveredServerReauthAction: recoveredAction
        )
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test(arguments: [WebViewEmptyStateStyle.disconnected, .inFlight])
    func connectionStylesRetry(style: WebViewEmptyStateStyle) {
        let recorder = Recorder()
        makeSUT(style: style, recorder: recorder).performPrimaryAction()
        #expect(recorder.retries == 1)
        #expect(recorder.reauthenticated.isEmpty)
    }

    @Test(arguments: [WebViewEmptyStateStyle.unauthenticated, .loggedOut, .recoveredServerNeedingReauthentication])
    func authenticationStylesReauthenticateWithTheFirstURL(style: WebViewEmptyStateStyle) {
        let recorder = Recorder()
        makeSUT(style: style, recorder: recorder).performPrimaryAction()
        #expect(recorder.reauthenticated == [.internal])
        #expect(recorder.retries == 0)
    }

    @Test func withoutURLsReauthenticationUsesTheExternalOne() {
        let recorder = Recorder()
        makeSUT(style: .unauthenticated, urlTypes: [], recorder: recorder).performPrimaryAction()
        #expect(recorder.reauthenticated == [.external])
    }

    @Test(arguments: [true, false])
    func aRecoveredServerReportsItsReauthentication(succeeds: Bool) async {
        let recorder = Recorder()
        let sut = makeSUT(
            style: .recoveredServerNeedingReauthentication,
            recorder: recorder,
            recoveredOutcome: succeeds ? .success(()) : .failure(ReauthError.failed)
        )

        sut.performPrimaryAction()

        #expect(recorder.recovered == [.internal])
        #expect(recorder.reauthenticated.isEmpty)
        // The outcome lands on the main queue.
        for _ in 0 ..< 5 {
            await Task.yield()
        }
    }

    @Test func rendersEveryStyleAndLayout() {
        let styles: [WebViewEmptyStateStyle] = [
            .disconnected,
            .inFlight,
            .unauthenticated,
            .loggedOut,
            .recoveredServerNeedingReauthentication,
            .clientCertificateRequired,
            .clientCertificateRejected,
        ]
        let recorder = Recorder()
        for style in styles {
            for showsErrorDetailsButton in [false, true] {
                let controller = UIHostingController(rootView: makeSUT(
                    style: style,
                    urlTypes: [.internal, .external, .remoteUI],
                    showsErrorDetailsButton: showsErrorDetailsButton,
                    recorder: recorder,
                    recoveredOutcome: .success(())
                ))
                controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
                controller.view.layoutIfNeeded()
            }
        }
        #expect(recorder.retries == 0)
    }
}
