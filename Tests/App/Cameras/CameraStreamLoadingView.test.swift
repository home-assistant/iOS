@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing

struct CameraStreamLoadingViewTests {
    @MainActor
    @Test func spinnerIsCenteredOnTheStream() {
        assertLightDarkSnapshots(of: CameraStreamLoadingView().background(.black))
    }
}
