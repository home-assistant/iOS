@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import WidgetKit

struct HAButtonStylesTests {
    @MainActor
    @Test func testAppButtonStyles() async throws {
        let listOfButtons = AnyView(
            List {
                VStack {
                    Button("primaryButton") {}
                        .buttonStyle(.primaryButton)
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
                    Button("pillButton") {}
                        .buttonStyle(.pillButton)
                }
                .padding(.horizontal)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        )

        assertLightDarkSnapshots(of: listOfButtons)
    }
}
