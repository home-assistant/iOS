import Foundation
@testable import Shared
import Testing

struct RemoteMediaCommandBurstTests {
    private let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")

    private var context: RemoteMediaTransportContext {
        .init(
            selection: selection,
            webhookURLs: [URL(string: "https://example.com/api/webhook/abc")!],
            secret: nil
        )
    }

    @Test func aFailedCommandReleasesItsClient() async {
        let recorder = Recorder()
        recorder.error = URLError(.timedOut)
        let burst = RemoteMediaCommandBurst(client: recorder.client)

        await #expect(throws: URLError.self) {
            try await burst.send(.next, selection: selection, context: context)
        }
        #expect(recorder.endCount == 1)

        // Cleanup is idempotent even when the burst later leaves scope.
        burst.finish()
        #expect(recorder.endCount == 1)
    }

    @Test func cancellingReconciliationReleasesItsClient() async throws {
        let recorder = Recorder()
        let readStarted = Signal()
        recorder.blockAfterRequest = 2
        recorder.block = { try await readStarted.waitUntilCancelled() }
        let burst = RemoteMediaCommandBurst(client: recorder.client)
        try await burst.send(.pause, selection: selection, context: context)

        let task = Task {
            await burst.reconcile(
                selection: selection,
                context: context,
                until: .notPlaying,
                delays: [.zero]
            ) { _ in }
        }
        await readStarted.waitUntilStarted()
        task.cancel()
        await task.value

        #expect(recorder.endCount == 1)
        #expect(recorder.requests == 2)
    }

    @Test func cancellingACommandReleasesItsClient() async {
        let recorder = Recorder()
        let commandStarted = Signal()
        recorder.blockAfterRequest = 1
        recorder.block = { try await commandStarted.waitUntilCancelled() }
        let burst = RemoteMediaCommandBurst(client: recorder.client)
        let task = Task {
            try await burst.send(.next, selection: selection, context: context)
        }

        await commandStarted.waitUntilStarted()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }

        #expect(recorder.endCount == 1)
        #expect(recorder.requests == 1)
    }

    @Test func oneBurstCannotReleaseAnotherBurstsClient() {
        let first = Recorder()
        let second = Recorder()
        let firstBurst = RemoteMediaCommandBurst(client: first.client)
        let secondBurst = RemoteMediaCommandBurst(client: second.client)

        firstBurst.finish()

        #expect(first.endCount == 1)
        #expect(second.endCount == 0)
        secondBurst.finish()
        #expect(second.endCount == 1)
    }

    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        var error: Error?
        var blockAfterRequest: Int?
        var block: (@Sendable () async throws -> Void)?
        private(set) var requests = 0
        private(set) var endCount = 0

        var client: RemoteMediaWebhookClient {
            RemoteMediaWebhookClient(
                perform: { [self] request in
                    let (error, block, shouldBlock) = beginRequest()
                    if let error { throw error }
                    if shouldBlock { try await block?() }
                    return (
                        Data(),
                        HTTPURLResponse(
                            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
                        )!
                    )
                },
                endBurst: { [self] in recordEnd() }
            )
        }

        private func beginRequest() -> (Error?, (@Sendable () async throws -> Void)?, Bool) {
            lock.lock()
            defer { lock.unlock() }
            requests += 1
            return (error, block, requests == blockAfterRequest)
        }

        private func recordEnd() {
            lock.lock()
            defer { lock.unlock() }
            endCount += 1
        }
    }

    private actor Signal {
        private var started: CheckedContinuation<Void, Never>?
        private var hasStarted = false

        func waitUntilCancelled() async throws {
            hasStarted = true
            started?.resume()
            started = nil
            try await Task.sleep(for: .seconds(30))
        }

        func waitUntilStarted() async {
            if hasStarted { return }
            await withCheckedContinuation { started = $0 }
        }
    }
}
