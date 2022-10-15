@testable import Shared
import XCTest

class ServerTests: XCTestCase {
    private func waitLoop() {
        let expectation = expectation(description: "run loop")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testSortOrder() {
        let servers: [Server] = [
            Server(
                identifier: "1",
                getter: {
                    with(.fake()) {
                        $0.sortOrder = 100
                    }
                }, setter: { _ in
                    true
                }
            ),
            Server(
                identifier: "2",
                getter: {
                    with(.fake()) {
                        $0.remoteName = "2"
                        $0.sortOrder = 50
                    }
                }, setter: { _ in
                    true
                }
            ),
            Server(
                identifier: "3",
                getter: {
                    with(.fake()) {
                        $0.remoteName = "1"
                        $0.sortOrder = 50
                    }
                }, setter: { _ in
                    true
                }
            ),
            Server(
                identifier: "4",
                getter: {
                    with(.fake()) {
                        $0.sortOrder = 1000
                    }
                }, setter: { _ in
                    true
                }
            ),
        ]

        let sorted = servers.sorted()
        XCTAssertEqual(sorted.map(\.identifier), ["3", "2", "1", "4"])
    }

    func testEquality() {
        let server_id1_1 = Server(identifier: "1", getter: { .fake() }, setter: { _ in true })
        let server_id1_2 = Server(identifier: "1", getter: { .fake() }, setter: { _ in true })
        let server_id2 = Server(identifier: "2", getter: { .fake() }, setter: { _ in true })
        let server_id3 = Server(identifier: "3", getter: { .fake() }, setter: { _ in true })

        XCTAssertEqual(server_id1_1, server_id1_1)
        XCTAssertEqual(server_id1_1, server_id1_2)
        XCTAssertNotEqual(server_id1_1, server_id3)
        XCTAssertNotEqual(server_id1_2, server_id3)
        XCTAssertNotEqual(server_id2, server_id3)
    }

    func testLocalName() {
        var serverInfo = ServerInfo.fake()
        serverInfo.remoteName = "remote_name1"

        let server = Server(identifier: "fake1", getter: { serverInfo }, setter: { serverInfo = $0; return true })

        XCTAssertEqual(server.info.name, "remote_name1")

        server.info.setSetting(value: "local_name1", for: .localName)
        XCTAssertEqual(server.info.name, "local_name1")

        server.info.setSetting(value: nil, for: .localName)
        XCTAssertEqual(server.info.name, "remote_name1")

        server.info.setSetting(value: "", for: .localName)
        XCTAssertEqual(server.info.name, "remote_name1")
    }

    func testNotifyInfoChange() {
        var info: ServerInfo = .fake()

        var setterResponseValue = true

        let server = Server(
            identifier: "test",
            getter: { info },
            setter: { info = $0; return setterResponseValue }
        )

        var notifiedInfos = [ServerInfo]()

        let token = server.observe { newInfo in
            notifiedInfos.append(newInfo)
        }

        server.info = info
        XCTAssertEqual(server.info, info)
        waitLoop()
        XCTAssertTrue(notifiedInfos.isEmpty)

        server.update { info in
            info.connection.webhookSecret = "update_1"
        }

        XCTAssertEqual(server.info.connection.webhookSecret, "update_1")
        waitLoop()

        XCTAssertEqual(notifiedInfos.count, 1)
        XCTAssertEqual(notifiedInfos[0].connection.webhookSecret, "update_1")

        setterResponseValue = false

        notifiedInfos.removeAll()

        server.update { info in
            info.connection.webhookSecret = "update_2"
        }

        waitLoop()
        XCTAssertTrue(notifiedInfos.isEmpty)

        setterResponseValue = true

        token.cancel()

        notifiedInfos.removeAll()

        server.update { info in
            info.connection.webhookSecret = "update_3"
        }

        waitLoop()

        XCTAssertTrue(notifiedInfos.isEmpty)
    }
}
