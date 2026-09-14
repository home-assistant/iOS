@testable import HomeAssistant
import XCTest

/// libwebrtc only installs its `NWPathMonitor`-based network monitor on iOS when this field trial
/// is on. Without it the peer connection gathers on every interface the device has — on cellular
/// that is several `pdp_ip` interfaces of which only the one carrying the current path can reach
/// anything — and the connectivity checks spend seconds on pairs that can never connect before
/// they reach the relay pair that can. With it, interfaces outside the current path are ignored,
/// which is the set WKWebView gathers on for the frontend's player.
final class WebRTCFieldTrialsTests: XCTestCase {
    func testTheNetworkPathMonitorTrialIsEnabled() {
        XCTAssertEqual(WebRTCFieldTrials.enabled["WebRTC-Network-UseNWPathMonitor"], "Enabled")
    }

    func testRegisteringTwiceIsHarmless() {
        WebRTCFieldTrials.registerBeforeCreatingFactory()
        WebRTCFieldTrials.registerBeforeCreatingFactory()
    }
}
