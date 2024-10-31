import Foundation

enum ControlRefreshDelay {
    /*
     Sometimes HA state is not updated as fast as controls,
     so we wait before finishing displaying it's new state
     */
    static func wait() async throws {
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
    }
}
