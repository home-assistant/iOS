@testable import Shared
import SwiftUI
import Testing

struct HATextFieldTests {
    @MainActor @Test func testSnapshot() async throws {
        let view = AnyView(
            VStack(spacing: DesignSystem.Spaces.two) {
                HATextField(placeholder: "Placeholder", text: .constant(""))
                HATextField(placeholder: "Placeholder", text: .constant("123"))
                HATextField(placeholder: "Placeholder", text: .constant("https://bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.com"))
            }
            .padding()
        )
        assertLightDarkSnapshots(of: view)
    }
}
