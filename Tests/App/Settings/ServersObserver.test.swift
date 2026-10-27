@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct ServersObserverTests {
    private func server(_ identifier: String, name: String, instanceID: String?) -> Server {
        Server.fake(identifier: .init(rawValue: identifier)) {
            $0.remoteName = name
            $0.instanceID = instanceID
            $0.sortOrder = 0
        }
    }

    private func withServers(_ servers: [Server], _ work: () -> Void) {
        let previous = Current.servers
        defer { Current.servers = previous }
        let manager = FakeServerManager()
        for server in servers {
            manager.add(identifier: server.identifier, serverInfo: server.info)
        }
        Current.servers = manager
        work()
    }

    @Test func distinctInstanceIDsShareNothing() {
        let servers = [
            server("a", name: "Home", instanceID: "instance-a"),
            server("b", name: "Chalet", instanceID: "instance-b"),
        ]

        #expect(ServersObserver.groupsSharingAnInstanceID(servers).isEmpty)
    }

    /// Servers too old to report an ID, or reporting an empty one, are never counted as sharing it.
    @Test func missingInstanceIDsShareNothing() {
        let servers = [
            server("a", name: "Home", instanceID: nil),
            server("b", name: "Chalet", instanceID: nil),
            server("c", name: "Office", instanceID: ""),
            server("d", name: "Cabin", instanceID: ""),
        ]

        #expect(ServersObserver.groupsSharingAnInstanceID(servers).isEmpty)
    }

    @Test func groupsServersByTheIDTheyShareInListOrder() {
        let servers = [
            server("a", name: "Home", instanceID: "shared-1"),
            server("b", name: "Office", instanceID: "shared-2"),
            server("c", name: "Alone", instanceID: "unique"),
            server("d", name: "Chalet", instanceID: "shared-1"),
            server("e", name: "Office copy", instanceID: "shared-2"),
        ]

        let groups = ServersObserver.groupsSharingAnInstanceID(servers).map { $0.map(\.identifier.rawValue) }

        #expect(groups == [["a", "d"], ["b", "e"]])
    }

    @Test func listsTheConflictsForTheExplanation() {
        withServers([
            server("a", name: "Home", instanceID: "shared"),
            server("b", name: "Chalet", instanceID: "shared"),
        ]) {
            let observer = ServersObserver()

            #expect(observer.serverIdentityConflicts.map { $0.map(\.name) } == [["Home", "Chalet"]])
        }
    }

    @Test func serversListWarnsAboutASharedID() {
        guard #available(iOS 18.0, *) else { return }

        withServers([
            server("a", name: "Domicile", instanceID: "shared"),
            server("b", name: "Chalet Hétu", instanceID: "shared"),
        ]) {
            assertLightDarkSnapshots(
                of: NavigationStack { List { ServersListView() } },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    @Test func serversListWithDistinctIDsHasNoWarning() {
        guard #available(iOS 18.0, *) else { return }

        withServers([
            server("a", name: "Domicile", instanceID: "instance-a"),
            server("b", name: "Chalet Hétu", instanceID: "instance-b"),
        ]) {
            assertLightDarkSnapshots(
                of: NavigationStack { List { ServersListView() } },
                drawHierarchyInKeyWindow: true
            )
        }
    }
}
