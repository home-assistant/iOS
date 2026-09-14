import Foundation
import WebRTC

enum WebRTCFieldTrials {
    static let enabled: [String: String] = [
        kRTCFieldTrialUseNWPathMonitor: kRTCFieldTrialEnabledValue,
    ]

    private static let registration: Void = RTCInitFieldTrialDictionary(enabled)

    static func registerBeforeCreatingFactory() {
        _ = registration
    }
}
