@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct JinjaTemplateButtonSnapshotTests {
    @Test func titlesRemainVisibleForEmptyTextAndRenderedResults() throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        let server = try #require(Current.servers.all.first)
        assertLightDarkSnapshots(
            of: Form {
                JinjaTemplateButton(server: server, title: "Minimum", text: .constant("12"), showsTitle: true)
                JinjaTemplateButton(server: server, title: "Maximum", text: .constant(""), showsTitle: true)
                JinjaTemplateButton(
                    server: server,
                    title: "Gauge color",
                    text: .constant("#ff9500"),
                    expectsColor: true,
                    showsTitle: true
                )
            },
            drawHierarchyInKeyWindow: true
        )
    }
}
