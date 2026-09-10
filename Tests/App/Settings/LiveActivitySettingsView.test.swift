@testable import HomeAssistant
import Testing
import UIKit

#if os(iOS) && !targetEnvironment(macCatalyst)
@available(iOS 17.2, *)
struct LiveActivitySettingsViewTests {
    @Test func testIPhoneIsSupportedBeforeIPadOS26() {
        #expect(LiveActivitySettingsView.isLiveActivitySupported(idiom: .phone, majorSystemVersion: 18))
    }

    @Test func testIPadIsUnsupportedBeforeIPadOS26() {
        #expect(!LiveActivitySettingsView.isLiveActivitySupported(idiom: .pad, majorSystemVersion: 18))
    }

    @Test func testIPadIsSupportedFromIPadOS26() {
        #expect(LiveActivitySettingsView.isLiveActivitySupported(idiom: .pad, majorSystemVersion: 26))
    }

    @MainActor
    @Test func testCurrentDeviceMatchesItsIdiomAndVersion() {
        let expected = LiveActivitySettingsView.isLiveActivitySupported(
            idiom: UIDevice.current.userInterfaceIdiom,
            majorSystemVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        )
        #expect(LiveActivitySettingsView().isLiveActivitySupportedOnDevice == expected)
    }
}
#endif
