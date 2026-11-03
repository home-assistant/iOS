@testable import HomeAssistant
import Testing

/// Creating the requester asks nothing yet: only `request()` makes the Bluetooth manager that
/// raises the system prompt, which a test must not do.
struct BluetoothAuthorizationRequesterTests {
    @Test func creatingTheRequesterDoesNotAskYet() {
        var answered = false
        let requester = BluetoothAuthorizationRequester { answered = true }
        withExtendedLifetime(requester) {
            #expect(!answered)
        }
    }
}
