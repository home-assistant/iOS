import CallKit
import Foundation

protocol CameraCallProviding: AnyObject {
    func setDelegate(_ delegate: CXProviderDelegate)
    func reportIncomingCall(uuid: UUID, update: CXCallUpdate, completion: @escaping (Error?) -> Void)
    func reportCallEnded(uuid: UUID, reason: CXCallEndedReason)
}
