@testable import Shared
import SharedTesting
import Testing

struct CornerRadiusSizesTests {
    @Test func testCornerRadiusSizes() async throws {
        assert(CornerRadiusSizes.micro == 2)
        assert(CornerRadiusSizes.half == 4)
        assert(CornerRadiusSizes.one == 8)
        assert(CornerRadiusSizes.oneAndHalf == 12)
        assert(CornerRadiusSizes.two == 16)
        assert(CornerRadiusSizes.three == 24)
        assert(CornerRadiusSizes.four == 32)
        assert(CornerRadiusSizes.five == 40)
        assert(CornerRadiusSizes.six == 48)
        assert(CornerRadiusSizes.oneAndMicro == 10)
        assert(CornerRadiusSizes.twoAndMicro == 18)
    }
}
