import Foundation
@testable import Shared
import Testing

/// Deep links and version strings built by `AppConstants`.
struct AppConstantsURLsTests {
    @Test func moreInfoLinksCarryTheServerName() throws {
        let url = try #require(AppConstants.openEntityMoreInfoDeeplinkURL(
            entityId: "light.kitchen",
            serverName: "Home"
        ))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "server", value: "Home")))
        #expect(items.contains { $0.value == "light.kitchen" })
    }

    @Test func todoLinksNeedAListAndAServer() {
        #expect(AppConstants.todoListAddItemURL(listId: "", serverId: "s") == nil)
        #expect(AppConstants.todoListAddItemURL(listId: "todo.x", serverId: "") == nil)
        #expect(AppConstants.todoListOpenURL(listId: "", serverId: "s") == nil)
        #expect(AppConstants.todoListOpenURL(listId: "todo.x", serverId: "") == nil)
        #expect(AppConstants.todoListOpenURL(listId: "todo.x", serverId: "s") != nil)
    }

    @Test func versionRequirementsNameTheCoreRelease() {
        let text = Version(major: 2024, minor: 3, patch: 0).coreRequiredString
        #expect(text.contains("core-2024.3"))
        #expect(AppConstants.createCustomWidgetURL.absoluteString.hasSuffix("createCustomWidget"))
        #expect(AppConstants.assistDeeplinkURL(serverId: "s", pipelineId: "p", startListening: true) != nil)
    }
}
