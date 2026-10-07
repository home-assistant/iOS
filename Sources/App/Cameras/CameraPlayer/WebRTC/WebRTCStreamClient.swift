import Foundation
import WebRTC

protocol WebRTCStreamClient: AnyObject {
    var delegate: WebRTCClientDelegate? { get set }
    var isConnectionAlive: Bool { get }
    func offer(completion: @escaping (_ sdp: String) -> Void)
    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void)
    func set(remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> Void)
    func renderRemoteVideo(to renderer: RTCVideoRenderer)
    func muteAudio()
    func unmuteAudio()
    func isAudioMuted() -> Bool
    func closeConnection()
}
