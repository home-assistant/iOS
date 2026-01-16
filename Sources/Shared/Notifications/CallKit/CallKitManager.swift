import AVFoundation
import CallKit
import Foundation
import PromiseKit
import Shared

public protocol CallKitManagerDelegate: AnyObject {
    func callKitManager(_ manager: CallKitManager, didAnswerCallWithInfo info: [String: Any])
}

public class CallKitManager: NSObject {
    public static let shared = CallKitManager()

    private let provider: CXProvider
    private let callController = CXCallController()
    public weak var delegate: CallKitManagerDelegate?

    private var activeCallInfo: [String: Any]?
    private var activeCallUUID: UUID?

    override private init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]

        // Set the app name for the incoming call UI
        config.localizedName = "Home Assistant"

        provider = CXProvider(configuration: config)

        super.init()

        provider.setDelegate(self, queue: nil)
    }

    public func reportIncomingCall(callerName: String, userInfo: [String: Any]) -> Promise<Void> {
        Promise { seal in
            let uuid = UUID()
            let update = CXCallUpdate()
            update.remoteHandle = CXHandle(type: .generic, value: callerName)
            update.hasVideo = false
            update.localizedCallerName = callerName

            activeCallInfo = userInfo
            activeCallUUID = uuid

            provider.reportNewIncomingCall(with: uuid, update: update) { error in
                if let error {
                    Current.Log.error("Failed to report incoming call: \(error)")
                    seal.reject(error)
                } else {
                    Current.Log.info("Successfully reported incoming call")
                    seal.fulfill(())
                }
            }
        }
    }

    private func endCall(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        callController.request(transaction) { error in
            if let error {
                Current.Log.error("Failed to end call: \(error)")
            } else {
                Current.Log.info("Successfully ended call")
            }
        }
    }
}

extension CallKitManager: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        Current.Log.info("CallKit provider did reset")
        activeCallInfo = nil
        activeCallUUID = nil
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Current.Log.info("User answered call")

        if let callInfo = activeCallInfo {
            // Notify delegate that call was answered
            delegate?.callKitManager(self, didAnswerCallWithInfo: callInfo)
        }

        // Mark the action as fulfilled
        action.fulfill()

        // End the call immediately since we just need to trigger opening Assist
        if let uuid = activeCallUUID {
            endCall(uuid: uuid)
        }

        activeCallInfo = nil
        activeCallUUID = nil
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Current.Log.info("Call ended")
        action.fulfill()
        activeCallInfo = nil
        activeCallUUID = nil
    }

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Current.Log.info("CallKit audio session activated")
    }

    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Current.Log.info("CallKit audio session deactivated")
    }
}
