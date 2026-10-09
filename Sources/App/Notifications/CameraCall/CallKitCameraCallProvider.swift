import CallKit
import Foundation
import Shared

final class CallKitCameraCallProvider: CameraCallProviding {
    private let provider: CXProvider

    init() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        configuration.includesCallsInRecents = false
        self.provider = CXProvider(configuration: configuration)
    }

    func setDelegate(_ delegate: CXProviderDelegate) {
        provider.setDelegate(delegate, queue: nil)
    }

    func reportIncomingCall(uuid: UUID, update: CXCallUpdate, completion: @escaping (Error?) -> Void) {
        provider.reportNewIncomingCall(with: uuid, update: update, completion: completion)
    }

    func reportCallEnded(uuid: UUID, reason: CXCallEndedReason) {
        provider.reportCall(with: uuid, endedAt: Current.date(), reason: reason)
    }
}
