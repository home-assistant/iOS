@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import WidgetKit

struct HAButtonStylesTests {
    @MainActor
    @Test func testAppButtonStyles() async throws {
        let listOfButtons = AnyView(
            VStack {
                Button("primaryButton") {}
                    .buttonStyle(.primaryButton)
                Button("outlinedButton") {}
                    .buttonStyle(.outlinedButton)
                Button("secondaryButton") {}
                    .buttonStyle(.secondaryButton)
                Button("negativeButton") {}
                    .buttonStyle(.negativeButton)
                Button("neutralButton") {}
                    .buttonStyle(.neutralButton)
                Button("secondaryNegativeButton") {}
                    .buttonStyle(.secondaryNegativeButton)
                Button("linkButton") {}
                    .buttonStyle(.linkButton)
                Button("criticalButton") {}
                    .buttonStyle(.criticalButton)
            }
            .padding(.horizontal)
            .listRowSeparator(.hidden)
        )

        // TODO: Figure it out a way that views with liquid glass applied show up in the snapshots
        assertLightDarkSnapshots(of: listOfButtons)
    }
}
