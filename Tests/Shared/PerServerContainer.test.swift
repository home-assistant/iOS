@testable import Shared
import XCTest

class PerServerContainerTests: XCTestCase {
    private var container: PerServerContainer<UUID>!
    private var servers: FakeServerManager!

    override func setUp() {
        super.setUp()
        servers = FakeServerManager(initial: 3)
        Current.servers = servers
    }

    func testLazy() {
        var constructorsInvoked = [UUID]()
        var destructorsInvoked = [UUID]()

        container = .init(lazy: true, constructor: { server in
            let uuid = UUID()
            constructorsInvoked.append(uuid)
            return .init(uuid) { serverDestruct, value in
                XCTAssertEqual(serverDestruct, server.identifier)
                XCTAssertEqual(value, uuid)
                destructorsInvoked.append(value)
            }
        })

        XCTAssertTrue(constructorsInvoked.isEmpty)
        XCTAssertTrue(destructorsInvoked.isEmpty)

        let value1 = container[servers.all[0]]
        XCTAssertEqual(value1, constructorsInvoked.last)
        XCTAssertEqual(value1, container[servers.all[0]])

        let value2 = container[servers.all[1]]
        XCTAssertEqual(value2, constructorsInvoked.last)
        XCTAssertEqual(value2, container[servers.all[1]])

        let value3 = container[servers.all[2]]
        XCTAssertEqual(value3, constructorsInvoked.last)
        XCTAssertEqual(value3, container[servers.all[2]])

        servers.remove(identifier: servers.all[0].identifier)
        servers.notify()
        XCTAssertEqual(value1, destructorsInvoked.last)

        servers.remove(identifier: servers.all[0].identifier)
        servers.notify()
        XCTAssertEqual(value2, destructorsInvoked.last)

        servers.remove(identifier: servers.all[0].identifier)
        servers.notify()
        XCTAssertEqual(value3, destructorsInvoked.last)

        constructorsInvoked.removeAll()

        _ = servers.addFake()
        servers.notify()
        XCTAssertTrue(constructorsInvoked.isEmpty)
    }

    func testRegular() {
        var constructorsInvoked = [UUID]()
        var destructorsInvoked = [UUID]()

        container = .init(lazy: false, constructor: { server in
            let uuid = UUID()
            constructorsInvoked.append(uuid)
            return .init(uuid) { serverDestruct, value in
                XCTAssertEqual(serverDestruct, server.identifier)
                XCTAssertEqual(value, uuid)
                destructorsInvoked.append(value)
            }
        })

        XCTAssertTrue(destructorsInvoked.isEmpty)

        let value1 = container[servers.all[0]]
        XCTAssertEqual(value1, constructorsInvoked[0])
        XCTAssertEqual(value1, container[servers.all[0]])

        let value2 = container[servers.all[1]]
        XCTAssertEqual(value2, constructorsInvoked[1])
        XCTAssertEqual(value2, container[servers.all[1]])

        let value3 = container[servers.all[2]]
        XCTAssertEqual(value3, constructorsInvoked[2])
        XCTAssertEqual(value3, container[servers.all[2]])

        servers.remove(identifier: servers.all[0].identifier)
        servers.notify()
        XCTAssertEqual(value1, destructorsInvoked.last)

        servers.remove(identifier: servers.all[0].identifier)
        servers.notify()
        XCTAssertEqual(value2, destructorsInvoked.last)

        servers.remove(identifier: servers.all[0].identifier)
        servers.notify()
        XCTAssertEqual(value3, destructorsInvoked.last)

        constructorsInvoked.removeAll()

        let new1 = servers.addFake()
        servers.notify()

        let valuenew1 = container[new1]
        XCTAssertEqual(valuenew1, constructorsInvoked[0])
        XCTAssertEqual(valuenew1, container[new1])

        let new2 = servers.addFake()
        servers.notify()

        let valuenew2 = container[new2]
        XCTAssertEqual(valuenew2, constructorsInvoked[1])
        XCTAssertEqual(valuenew2, container[new2])
    }

    func testChangingConstructor() {
        var constructorsInvoked_old = [UUID]()
        var constructorsInvoked_new = [UUID]()
        var destructorsInvoked_new = [UUID]()
        var destructorsInvoked_old = [UUID]()

        container = .init(lazy: false, constructor: { server in
            let uuid = UUID()
            constructorsInvoked_old.append(uuid)
            return .init(uuid) { serverDestruct, value in
                XCTAssertEqual(serverDestruct, server.identifier)
                XCTAssertEqual(value, uuid)
                destructorsInvoked_old.append(value)
            }
        })

        container.constructor = { server in
            let uuid = UUID()
            constructorsInvoked_new.append(uuid)
            return .init(uuid) { serverDestruct, value in
                XCTAssertEqual(serverDestruct, server.identifier)
                XCTAssertEqual(value, uuid)
                destructorsInvoked_new.append(value)
            }
        }

        XCTAssertEqual(Set(constructorsInvoked_old), Set(destructorsInvoked_old))

        XCTAssertEqual(constructorsInvoked_new.count, 3)
    }

    func testDestructDeinitializer() {
        var constructorsInvoked = [UUID]()
        var destructorsInvoked = [UUID]()

        autoreleasepool {
            container = PerServerContainer<UUID>(lazy: false, constructor: { server in
                let uuid = UUID()
                constructorsInvoked.append(uuid)
                return .init(uuid) { serverDestruct, value in
                    XCTAssertEqual(serverDestruct, server.identifier)
                    XCTAssertEqual(value, uuid)
                    destructorsInvoked.append(value)
                }
            })

            container = nil
        }

        XCTAssertEqual(Set(constructorsInvoked), Set(destructorsInvoked))
    }
}
