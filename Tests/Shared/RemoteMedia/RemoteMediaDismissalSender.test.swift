import Foundation
@testable import Shared
import Testing

/// A dismissal is best effort, and its failure must be invisible to everything else.
struct RemoteMediaDismissalSenderTests {
    private let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")

    private func end(sequence: Int = 10) -> RemoteMediaFollowEnd {
        .init(
            pending: .init(
                selection: selection,
                lifetime: .init(generation: "A", sequence: sequence)
            ),
            context: .init(
                selection: selection,
                webhookURLs: [URL(string: "https://example.com/api/webhook/abc")!],
                secret: nil
            )
        )
    }

    private final class Recorder: @unchecked Sendable {
        var sent: [RemoteMediaSessionDismissal] = []
        var failure: Error?

        var perform: RemoteMediaDismissalSender.Perform {
            { [self] end in
                sent.append(end.dismissal)
                if let failure { throw failure }
            }
        }
    }

    @Test func theDismissalIsSentOnce() async {
        let recorder = Recorder()
        let accepted = await RemoteMediaDismissalSender(perform: recorder.perform).send(end())
        #expect(accepted)
        #expect(recorder.sent == [
            .init(sessionId: selection.id, generation: "A", generationSequence: 10),
        ])
    }

    /// Nothing is retried here and nothing is thrown: the local session has already ended. The
    /// answer is reported instead, so the caller knows whether the record is still owed.
    @Test func aFailureIsReportedRatherThanThrownOrRetried() async {
        let recorder = Recorder()
        recorder.failure = URLError(.notConnectedToInternet)
        let accepted = await RemoteMediaDismissalSender(perform: recorder.perform).send(end())
        #expect(!accepted)
        #expect(recorder.sent.count == 1)
    }
}
