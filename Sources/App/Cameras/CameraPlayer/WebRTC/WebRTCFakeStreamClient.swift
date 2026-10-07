#if DEBUG
import Foundation
import WebRTC

final class WebRTCFakeStreamClient: WebRTCStreamClient {
    struct RemoteCandidate: Equatable {
        let sdp: String
        let sdpMid: String?
        let sdpMLineIndex: Int32
    }

    let configuration: WebRTCClientConfiguration
    weak var delegate: WebRTCClientDelegate?
    var isConnectionAlive = true
    var offerSDP = "v=0\r\no=- 1 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n"
    private(set) var offerCount = 0
    private(set) var remoteDescriptions: [String] = []
    private(set) var remoteCandidates: [RemoteCandidate] = []
    private(set) var rendererCount = 0
    private(set) var isClosed = false
    private var isMuted = true

    init(configuration: WebRTCClientConfiguration) {
        self.configuration = configuration
    }

    func offer(completion: @escaping (_ sdp: String) -> Void) {
        offerCount += 1
        completion(offerSDP)
    }

    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        remoteDescriptions.append(remoteSdp.sdp)
        completion(nil)
    }

    func set(remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> Void) {
        remoteCandidates.append(RemoteCandidate(
            sdp: remoteCandidate.sdp,
            sdpMid: remoteCandidate.sdpMid,
            sdpMLineIndex: remoteCandidate.sdpMLineIndex
        ))
        completion(nil)
    }

    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        rendererCount += 1
    }

    func muteAudio() {
        isMuted = true
    }

    func unmuteAudio() {
        isMuted = false
    }

    func isAudioMuted() -> Bool {
        isMuted
    }

    func closeConnection() {
        isClosed = true
    }

    func discoverLocalCandidate(_ sdp: String, sdpMid: String? = "0", sdpMLineIndex: Int32 = 0) {
        delegate?.webRTCClient(
            self,
            didDiscoverLocalCandidate: RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        )
    }

    func changeConnectionState(_ state: RTCIceConnectionState) {
        delegate?.webRTCClient(self, didChangeConnectionState: state)
    }
}
#endif
