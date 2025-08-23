@testable import Shared
import SharedTesting
import Testing

struct SpacesTests {
    @Test func testSpacesSizes() async throws {
        assert(Spaces.half == 4)
        assert(Spaces.one == 8)
        assert(Spaces.oneAndHalf == 12)
        assert(Spaces.two == 16)
        assert(Spaces.three == 24)
        assert(Spaces.four == 32)
        assert(Spaces.five == 40)
        assert(Spaces.six == 48)
    }
}
