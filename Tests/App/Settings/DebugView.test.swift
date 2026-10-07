@testable import HomeAssistant
import Testing

@MainActor
struct DebugViewTests {
    /// Every row of the debugging screen is built inline in its body, so nothing else in the suite
    /// runs that code: a row that stopped resolving — a missing icon, a destination that no longer
    /// compiles into the list — would only show up when someone opened the screen by hand.
    /// Building the body is the assertion; it traps if a row cannot be constructed.
    @Test func theScreenBuildsItsRows() {
        _ = DebugView().body
    }
}
