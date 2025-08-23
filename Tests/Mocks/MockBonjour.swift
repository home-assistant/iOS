import Foundation
import Shared

final class MockBonjour: BonjourProtocol {
    var observer: (any BonjourObserver)?

    var startCalled = false
    var stopCalled = false

    func start() {
        startCalled = true
    }

    func stop() {
        stopCalled = true
    }
}
