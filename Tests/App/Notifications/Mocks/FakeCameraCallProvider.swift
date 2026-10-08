import CallKit
@testable import HomeAssistant

final class FakeCameraCallProvider: CameraCallProviding {
    struct EndedCall: Equatable {
        let uuid: UUID
        let reason: CXCallEndedReason
    }

    private(set) weak var delegate: CXProviderDelegate?
    private(set) var reportedCalls: [(uuid: UUID, update: CXCallUpdate)] = []
    private(set) var endedCalls: [EndedCall] = []
    var reportError: Error?

    func setDelegate(_ delegate: CXProviderDelegate) {
        self.delegate = delegate
    }

    func reportIncomingCall(uuid: UUID, update: CXCallUpdate, completion: @escaping (Error?) -> Void) {
        reportedCalls.append((uuid: uuid, update: update))
        completion(reportError)
    }

    func reportCallEnded(uuid: UUID, reason: CXCallEndedReason) {
        endedCalls.append(.init(uuid: uuid, reason: reason))
    }
}
