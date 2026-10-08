import Foundation
import PromiseKit
import Shared

struct CameraCallCommandHandler: NotificationCommandHandler {
    enum CameraCallCommandError: Error {
        case missingCamera
    }

    var makeRequest: ([String: Any]) -> CameraCallRequest? = { CameraCallRequest(payload: $0) }
    var reportIncomingCall: (CameraCallRequest, @escaping (Error?) -> Void) -> Void = {
        CameraCallManager.shared.reportIncomingCall($0, completion: $1)
    }

    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard let request = makeRequest(payload) else {
            Current.Log.error("Ignoring a camera call without a camera entity: \(payload)")
            return .init(error: CameraCallCommandError.missingCamera)
        }
        return Promise { seal in
            reportIncomingCall(request) { error in
                if let error {
                    seal.reject(error)
                } else {
                    seal.fulfill(())
                }
            }
        }
    }
}
