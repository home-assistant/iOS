@testable import HomeAssistant
@testable import Shared
import Testing

struct OnboardingServerIdentityRequestTests {
    private final class Recorder {
        var decisions: [OnboardingServerIdentityRequest.Decision] = []
        var cancellations = 0
    }

    private func makeRequest(_ recorder: Recorder) -> OnboardingServerIdentityRequest {
        OnboardingServerIdentityRequest(
            newServer: ServerIdentityConflictingServer(name: "Chalet", address: nil),
            existingServer: ServerIdentityConflictingServer(name: "Home", address: nil),
            onDecision: { recorder.decisions.append($0) },
            onCancel: { recorder.cancellations += 1 }
        )
    }

    @Test func answersOnlyOnce() {
        let recorder = Recorder()
        let request = makeRequest(recorder)

        request.addAsSeparateServer()
        request.replaceExistingServer()
        request.cancel()

        #expect(recorder.decisions == [.separate])
        #expect(recorder.cancellations == 0)
    }

    @Test func replacing() {
        let recorder = Recorder()
        let request = makeRequest(recorder)

        request.replaceExistingServer()
        request.addAsSeparateServer()

        #expect(recorder.decisions == [.replace])
    }

    /// The sheet disappearing after an answer cancels too, which must not undo the answer.
    @Test func cancellingAfterwardsIsIgnored() {
        let recorder = Recorder()
        let request = makeRequest(recorder)

        request.cancel()
        request.cancel()
        request.addAsSeparateServer()

        #expect(recorder.cancellations == 1)
        #expect(recorder.decisions.isEmpty)
    }

    @Test func isAnAuthFlowDestinationComparedByIdentity() {
        let recorder = Recorder()
        let request = makeRequest(recorder)
        let other = makeRequest(recorder)
        let destination = OnboardingDestination.serverIdentity(request)

        #expect(destination.isAuthFlowStep)
        #expect(destination == .serverIdentity(request))
        #expect(destination != .serverIdentity(other))
        #expect(destination != .serversList)
        #expect(destination.hashValue == OnboardingDestination.serverIdentity(request).hashValue)
    }
}
