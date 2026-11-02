@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// What a restored web view window brings back: the page it was on and the server it showed, from a
/// user activity, from a state restoration coder, or from a server handed over directly.
@Suite(.sharedState)
struct WebViewRestorationTypeTests {
    private func withServers(_ body: (FakeServerManager) throws -> Void) rethrows {
        let previousServers = Current.servers
        let servers = FakeServerManager(initial: 1)
        Current.servers = servers
        defer { Current.servers = previousServers }
        try body(servers)
    }

    @Test func noActivityRestoresNothing() {
        #expect(WebViewRestorationType(nil) == nil)
    }

    @Test func anActivityRestoresItsPageAndServer() throws {
        try withServers { servers in
            let server = try #require(servers.all.first)
            let url = try #require(URL(string: "http://homeassistant.local:8123/lovelace/1"))
            let activity = NSUserActivity(activityType: "restore")
            activity.userInfo = [
                RestorableStateKey.lastURL.rawValue: url,
                RestorableStateKey.server.rawValue: server.identifier.rawValue,
            ]

            let restoration = try #require(WebViewRestorationType(activity))
            #expect(restoration.initialURL == url)
            #expect(restoration.server?.identifier == server.identifier)
        }
    }

    @Test func anActivityWithoutStateRestoresNothing() throws {
        try withServers { _ in
            let restoration = try #require(WebViewRestorationType(NSUserActivity(activityType: "restore")))
            #expect(restoration.initialURL == nil)
        }
    }

    @Test func aCoderRestoresItsPageAndServer() throws {
        try withServers { servers in
            let server = try #require(servers.all.first)
            let url = try #require(URL(string: "http://homeassistant.local:8123/energy"))
            let archiver = NSKeyedArchiver(requiringSecureCoding: true)
            archiver.encode(url as NSURL, forKey: RestorableStateKey.lastURL.rawValue)
            archiver.encode(server.identifier.rawValue as NSString, forKey: RestorableStateKey.server.rawValue)
            archiver.finishEncoding()
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)

            let restoration = WebViewRestorationType.coder(unarchiver)
            #expect(restoration.initialURL == url)
            #expect(restoration.server?.identifier == server.identifier)
        }
    }

    @Test func aServerRestoresOnlyItself() {
        let server = Server.fake()
        let restoration = WebViewRestorationType.server(server)
        #expect(restoration.initialURL == nil)
        #expect(restoration.server?.identifier == server.identifier)
    }
}
