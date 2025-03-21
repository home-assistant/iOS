@testable import Shared
import Testing

struct OptionalsDefaultTests {
    @Test func testString() async throws {
        let string: String? = nil
        assert(string.orEmpty == "", "Default value for string should be empty")
    }

    @Test func testBool() async throws {
        let bool: Bool? = nil
        assert(bool.orFalse == false, "Default value for bool should be false")
    }

    @Test func testFloat() async throws {
        let float: Float? = nil
        assert(float.orZero == 0, "Default value for float should be 0")
    }
}
