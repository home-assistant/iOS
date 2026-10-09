import AVFoundation
import CallKit
import Foundation
import Shared

final class CameraCallManager: NSObject {
    struct Timing {
        var unansweredTimeout: TimeInterval

        static let production = Timing(unansweredTimeout: 30)
    }

    typealias MakeSession = (_ server: Server, _ cameraEntityId: String) -> CameraMicrophoneSessionProtocol

    private struct Call {
        let uuid: UUID
        let request: CameraCallRequest
        var session: CameraMicrophoneSessionProtocol?
        var isMuted = false
        var unansweredWorkItem: DispatchWorkItem?
    }

    static let shared = CameraCallManager()

    var activeCallUUID: UUID? {
        call?.uuid
    }

    private let provider: CameraCallProviding
    private let audio: CameraCallAudio
    private let makeSession: MakeSession
    private let makeUUID: () -> UUID
    private let timing: Timing
    private var call: Call?

    init(
        provider: CameraCallProviding = CallKitCameraCallProvider(),
        audio: CameraCallAudio = WebRTCCameraCallAudio(),
        makeSession: @escaping MakeSession = { server, cameraEntityId in
            CameraMicrophoneSession(server: server, cameraEntityId: cameraEntityId, makeClient: {
                WebRTCClient(configuration: $0, media: .call)
            })
        },
        makeUUID: @escaping () -> UUID = UUID.init,
        timing: Timing = .production
    ) {
        self.provider = provider
        self.audio = audio
        self.makeSession = makeSession
        self.makeUUID = makeUUID
        self.timing = timing
        super.init()
        provider.setDelegate(self)
    }

    func reportIncomingCall(_ request: CameraCallRequest, completion: @escaping (Error?) -> Void) {
        guard call == nil else {
            Current.Log.info("Ignoring a call from \(request.cameraEntityId) while another call is in progress")
            completion(nil)
            return
        }
        let uuid = makeUUID()
        call = Call(uuid: uuid, request: request)
        Current.Log.info("Reporting an incoming call from \(request.cameraEntityId)")
        provider.reportIncomingCall(uuid: uuid, update: Self.update(for: request)) { [weak self] error in
            DispatchQueue.main.async {
                self?.handleReportResult(error, uuid: uuid)
                completion(error)
            }
        }
    }

    @discardableResult
    func answerCall(uuid: UUID) -> Bool {
        guard var call, call.uuid == uuid else { return false }
        call.unansweredWorkItem?.cancel()
        call.unansweredWorkItem = nil
        audio.prepareForCall()
        let session = makeSession(call.request.server, call.request.cameraEntityId)
        call.session = session
        self.call = call
        session.onEnd = { [weak self] error in
            Current.Log.info("Call from \(call.request.cameraEntityId) lost its stream: \(error.code)")
            self?.endCallFromCamera(uuid: uuid)
        }
        session.start { [weak self] result in
            guard let self, self.call?.uuid == uuid else { return }
            switch result {
            case .success:
                session.setMicrophoneEnabled(!(self.call?.isMuted ?? false))
            case let .failure(error):
                Current.Log.error("Call from \(call.request.cameraEntityId) could not connect: \(error.code)")
                endCallFromCamera(uuid: uuid)
            }
        }
        return true
    }

    @discardableResult
    func endCall(uuid: UUID) -> Bool {
        guard let call, call.uuid == uuid else { return false }
        tearDown(call)
        return true
    }

    @discardableResult
    func setMuted(_ muted: Bool, uuid: UUID) -> Bool {
        guard call?.uuid == uuid else { return false }
        call?.isMuted = muted
        call?.session?.setMicrophoneEnabled(!muted)
        return true
    }

    func reset() {
        guard let call else { return }
        tearDown(call)
    }

    func audioSessionDidActivate(_ audioSession: AVAudioSession) {
        audio.activate(audioSession)
    }

    func audioSessionDidDeactivate(_ audioSession: AVAudioSession) {
        audio.deactivate(audioSession)
    }

    static func update(for request: CameraCallRequest) -> CXCallUpdate {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: request.cameraEntityId)
        update.localizedCallerName = request.cameraName
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        return update
    }

    private func handleReportResult(_ error: Error?, uuid: UUID) {
        guard call?.uuid == uuid else { return }
        if let error {
            Current.Log.error("CallKit did not accept the incoming call: \(error.localizedDescription)")
            call = nil
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let call, call.uuid == uuid, call.session == nil else { return }
            Current.Log.info("Call from \(call.request.cameraEntityId) was not answered")
            tearDown(call)
            provider.reportCallEnded(uuid: uuid, reason: .unanswered)
        }
        call?.unansweredWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timing.unansweredTimeout, execute: workItem)
    }

    private func endCallFromCamera(uuid: UUID) {
        guard let call, call.uuid == uuid else { return }
        tearDown(call)
        provider.reportCallEnded(uuid: uuid, reason: .failed)
    }

    private func tearDown(_ call: Call) {
        self.call = nil
        call.unansweredWorkItem?.cancel()
        guard let session = call.session else { return }
        session.stop()
        audio.finishCall()
    }
}

extension CameraCallManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        reset()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if answerCall(uuid: action.callUUID) {
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        endCall(uuid: action.callUUID)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if setMuted(action.isMuted, uuid: action.callUUID) {
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        audioSessionDidActivate(audioSession)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        audioSessionDidDeactivate(audioSession)
    }
}
