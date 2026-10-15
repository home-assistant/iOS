@testable import HomeAssistant
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

struct ViewZoomTransitionTests {
    /// Both halves of the pair apply to a view and render; the modifiers themselves draw nothing.
    @MainActor @Test func sourceAndDestinationRender() async throws {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: AnyView(ZoomTransitionPair()),
            layout: .fixed(width: 200, height: 120),
            named: "zoom-transition-pair"
        )
    }

    private struct ZoomTransitionPair: View {
        @Namespace private var namespace

        var body: some View {
            VStack {
                Text("Source")
                    .zoomTransitionSource(id: "entry", in: namespace)
                Text("Destination")
                    .zoomNavigationTransition(sourceID: "entry", in: namespace)
            }
            .padding()
        }
    }
}
