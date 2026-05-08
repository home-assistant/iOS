import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct NFCTagApprovalTests {
    private let legacyAllowedTagsKey = "allowedTags"

    @Test("Unapproved Home Assistant tags require approval")
    func unapprovedTagsRequireApproval() throws {
        try withAllowedTagDatabase {
            let result = iOSTagManager().handle(userActivity: userActivity(tag: "front-door"))

            guard case let .requiresApproval(tag, type) = result else {
                Issue.record("Expected tag to require approval")
                return
            }

            #expect(tag == "front-door")
            #expect(isGeneric(type))
        }
    }

    @Test("Allowed Home Assistant tags are handled immediately")
    func allowedTagsAreHandledImmediately() throws {
        try withAllowedTagDatabase {
            let previousServers = Current.servers
            Current.servers = FakeServerManager(initial: 0)
            defer { Current.servers = previousServers }

            AllowedTag.add("front-door")

            let result = iOSTagManager().handle(userActivity: userActivity(tag: "front-door"))

            guard case let .handled(type) = result else {
                Issue.record("Expected allowed tag to be handled")
                return
            }

            #expect(isGeneric(type))
        }
    }

    private func withAllowedTagDatabase(perform work: () throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")

        Current.settingsStore.prefs.removeObject(forKey: legacyAllowedTagsKey)
        try AllowedTagTable().createIfNeeded(database: database)
        Current.database = { database }

        defer {
            Current.database = previousDatabase
            Current.settingsStore.prefs.removeObject(forKey: legacyAllowedTagsKey)
        }

        try work()
    }

    private func userActivity(tag: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = URL(string: "https://www.home-assistant.io/tag/\(tag)")!
        return activity
    }

    private func isGeneric(_ type: TagManagerHandleResult.HandledType) -> Bool {
        if case .generic = type {
            return true
        } else {
            return false
        }
    }
}
