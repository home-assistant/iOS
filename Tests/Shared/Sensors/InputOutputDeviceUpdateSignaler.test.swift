import Foundation
@testable import Shared
import XCTest

final class InputOutputDeviceUpdateSignalerTests: XCTestCase {
    func testOverlappingUpdatesRegisterOnlyOneListener() {
        let signaler = InputOutputDeviceUpdateSignaler(signal: {})
        let firstRegistrationStarted = DispatchSemaphore(value: 0)
        let finishFirstRegistration = DispatchSemaphore(value: 0)
        let secondUpdateFinished = DispatchSemaphore(value: 0)
        let updates = DispatchGroup()
        let property = MockProperty { registration, _ in
            if registration == 1 {
                firstRegistrationStarted.signal()
                _ = finishFirstRegistration.wait(timeout: .now() + 10)
            }
        }

        // Keep the first framework call in flight while another sensor update attempts to register.
        // The old contains/addListener/insert sequence installs a second listener in this window.
        DispatchQueue.global().async(group: updates) {
            signaler.addObserver(object: .invalid, property: property)
        }
        defer {
            finishFirstRegistration.signal()
            XCTAssertEqual(updates.wait(timeout: .now() + 5), .success)
        }
        guard firstRegistrationStarted.wait(timeout: .now() + 5) == .success else {
            return XCTFail("The first listener registration never started")
        }

        DispatchQueue.global().async(group: updates) {
            signaler.addObserver(object: .invalid, property: property)
            secondUpdateFinished.signal()
        }

        // This also checks that framework calls do not hold the bookkeeping lock.
        XCTAssertEqual(secondUpdateFinished.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(property.registrationCount, 1)
    }

    func testRemovedObjectCanBeRegisteredAgain() {
        let signaler = InputOutputDeviceUpdateSignaler(signal: {})
        let property = MockProperty()

        signaler.removeObserver(object: .invalid)
        signaler.addObserver(object: .invalid, property: property)
        signaler.addObserver(object: .invalid, property: property)
        XCTAssertEqual(property.registrationCount, 1)

        signaler.removeObserver(object: .invalid)
        signaler.addObserver(object: .invalid, property: property)
        signaler.addObserver(object: .invalid, property: property)
        XCTAssertEqual(property.registrationCount, 2)
    }

    func testListenerCanReenterRegistrationWithoutDeadlocking() {
        let signaler = InputOutputDeviceUpdateSignaler(signal: {})
        let reentrantProperty = MockProperty()
        let property = MockProperty { _, _ in
            signaler.addObserver(object: .invalid, property: reentrantProperty)
        }
        let finished = expectation(description: "Reentrant registration returns")

        DispatchQueue.global().async {
            signaler.addObserver(object: .invalid, property: property)
            finished.fulfill()
        }

        wait(for: [finished], timeout: 5)
        XCTAssertEqual(property.registrationCount, 1)
        XCTAssertEqual(reentrantProperty.registrationCount, 0)
    }

    func testListenerSignalsSensorUpdate() {
        let signaled = expectation(description: "Listener signals a sensor update")
        let signaler = InputOutputDeviceUpdateSignaler { signaled.fulfill() }
        let property = MockProperty { _, handler in handler() }

        signaler.addObserver(object: .invalid, property: property)

        wait(for: [signaled], timeout: 1)
    }

    func testConcurrentRegistrationAndRemoval() {
        let signaler = InputOutputDeviceUpdateSignaler(signal: {})
        let property = MockProperty()

        // Exercise reads and mutations together, including under Thread Sanitizer.
        DispatchQueue.concurrentPerform(iterations: 1000) { iteration in
            if iteration.isMultiple(of: 2) {
                signaler.addObserver(object: .invalid, property: property)
            } else {
                signaler.removeObserver(object: .invalid)
            }
        }

        signaler.removeObserver(object: .invalid)
        let registrationsBefore = property.registrationCount
        signaler.addObserver(object: .invalid, property: property)
        signaler.addObserver(object: .invalid, property: property)
        XCTAssertEqual(property.registrationCount, registrationsBefore + 1)
    }

    private final class MockProperty: HACoreBlahProperty {
        typealias ValueType = UInt32

        private let lock = NSLock()
        private var registrations = 0
        private let onAddListener: (Int, () -> Void) -> Void

        init(onAddListener: @escaping (Int, () -> Void) -> Void = { _, _ in }) {
            self.onAddListener = onAddListener
        }

        var registrationCount: Int {
            lock.withLock { registrations }
        }

        func addListener(objectID: UInt32, handler: @escaping () -> Void) -> OSStatus {
            let registration = lock.withLock {
                registrations += 1
                return registrations
            }
            onAddListener(registration, handler)
            return 0
        }

        func getPropertyDataSize(objectID: UInt32, dataSize: UnsafeMutablePointer<UInt32>) -> OSStatus {
            XCTFail("Observer registration should not read property data")
            return -1
        }

        func getPropertyData(objectID: UInt32, dataSize: UInt32, output: UnsafeMutableRawPointer) -> OSStatus {
            XCTFail("Observer registration should not read property data")
            return -1
        }
    }
}
