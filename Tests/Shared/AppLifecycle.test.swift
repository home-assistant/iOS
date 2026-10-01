import Foundation
@testable import Shared
import Testing
import UIKit

struct AppLifecycleTests {
    /// On iOS every lifecycle name is UIKit's own, so whoever observes through `AppLifecycle` hears what
    /// UIKit posts.
    @Test func namesMatchUIKit() {
        #expect(AppLifecycle.didBecomeActiveNotification == UIApplication.didBecomeActiveNotification)
        #expect(AppLifecycle.willResignActiveNotification == UIApplication.willResignActiveNotification)
        #expect(AppLifecycle.didEnterBackgroundNotification == UIApplication.didEnterBackgroundNotification)
        #expect(AppLifecycle.willEnterForegroundNotification == UIApplication.willEnterForegroundNotification)
        #expect(AppLifecycle.willTerminateNotification == UIApplication.willTerminateNotification)
    }
}
