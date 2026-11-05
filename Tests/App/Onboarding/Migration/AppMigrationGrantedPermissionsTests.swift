import Foundation
@testable import HomeAssistant
import Testing

struct AppMigrationGrantedPermissionsTests {
    @Test func theSnapshotComesBackWithinItsBudget() async {
        let clock = ContinuousClock()
        let started = clock.now
        let granted = await AppMigrationGrantedPermissions.current()
        #expect(clock.now - started < AppMigrationGrantedPermissions.budget + .seconds(2))
        #expect(Set(granted).count == granted.count)
    }
}
