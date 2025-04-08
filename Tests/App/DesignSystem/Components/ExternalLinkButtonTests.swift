@testable import Shared
import SharedTesting
import SwiftUI
import Testing

struct ExternalLinkButtonTests {
    @MainActor
    @Test func testExternalLinkButton() async throws {
        let view = ExternalLinkButton(
            icon: Image(systemSymbol: .heart),
            title: "This is a title",
            url: URL(string: "https://google.com")!,
            tint: .blue,
            background: Color(uiColor: .secondarySystemFill)
        )

        assertLightDarkSnapshots(of: view)
    }
}
