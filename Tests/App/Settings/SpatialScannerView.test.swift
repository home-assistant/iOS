#if os(iOS) && !targetEnvironment(macCatalyst)
@testable import HomeAssistant
import SwiftUI
import Testing

struct SpatialScannerViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: NavigationStack {
            SpatialScannerView()
        })
    }
}
#endif
