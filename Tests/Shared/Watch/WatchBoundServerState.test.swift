import Foundation
@testable import Shared
import Testing

struct WatchBoundServerStateTests {
    private func encoded(_ servers: [String: ServerInfo]) throws -> Data {
        try JSONEncoder().encode(servers)
    }

    private func decoded(_ data: Data) throws -> [String: ServerInfo] {
        try JSONDecoder().decode([String: ServerInfo].self, from: data)
    }

    @Test func stampsEveryServerWithItsDeviceName() throws {
        let plain = ServerInfo.fake()
        var overridden = ServerInfo.fake()
        overridden.setSetting(value: "Kitchen Phone", for: .overrideDeviceName)
        let state = try encoded(["one": plain, "two": overridden])

        let stamped = try decoded(WatchBoundServerState.stamp(state) { info in
            info.setting(for: .overrideDeviceName) ?? "Bruno's iPhone"
        })

        #expect(stamped["one"]?.setting(for: .companionDeviceName) == "Bruno's iPhone")
        #expect(stamped["two"]?.setting(for: .companionDeviceName) == "Kitchen Phone")
        // Nothing else about the servers moved.
        #expect(stamped["two"]?.setting(for: .overrideDeviceName) == "Kitchen Phone")
        #expect(stamped["one"]?.remoteName == plain.remoteName)
        #expect(stamped["one"]?.connection == plain.connection)
        #expect(stamped["one"]?.token == plain.token)
        #expect(stamped["one"]?.version == plain.version)
    }

    @Test func encodedUsesThePhonesRegistrationName() throws {
        let previousServers = Current.servers
        let previousDeviceName = Current.device.deviceName
        defer {
            Current.servers = previousServers
            Current.device.deviceName = previousDeviceName
        }
        Current.device.deviceName = { "Bruno's iPhone" }
        var overridden = ServerInfo.fake()
        overridden.setSetting(value: "Kitchen Phone", for: .overrideDeviceName)
        let state = try encoded(["plain": .fake(), "named": overridden])
        Current.servers = StatefulFakeServerManager(state: state)

        let stamped = try decoded(WatchBoundServerState.encoded())

        #expect(stamped["plain"]?.setting(for: .companionDeviceName) == "Bruno's iPhone")
        #expect(stamped["named"]?.setting(for: .companionDeviceName) == "Kitchen Phone")
    }

    @Test func passesUnreadableStateThrough() {
        let empty = Data()
        #expect(WatchBoundServerState.stamp(empty) { _ in "Bruno's iPhone" } == empty)

        let garbage = Data("not servers".utf8)
        #expect(WatchBoundServerState.stamp(garbage) { _ in "Bruno's iPhone" } == garbage)
    }
}

/// A fake server manager whose `restorableState()` is a given encoding, for exercising the
/// watch-bound stamping end to end.
private final class StatefulFakeServerManager: FakeServerManager {
    private let state: Data

    init(state: Data) {
        self.state = state
        super.init()
    }

    override func restorableState() -> Data {
        state
    }
}
