import Foundation
@testable import Shared
import Testing

@Suite("Float+HA Extensions Tests")
struct FloatHAExtensionsTests {
    // MARK: - Float? orZero Tests

    @Test("Given nil float when getting orZero then returns zero")
    func orZeroWithNil() async throws {
        let nilFloat: Float? = nil
        #expect(nilFloat.orZero == 0.0, "nil float should return 0.0")
    }

    @Test(
        "Given non-nil float when getting orZero then returns original value",
        arguments: [
            Float(0.0),
            Float(1.0),
            Float(-1.0),
            Float(42.5),
            Float(-42.5),
            Float(0.123456),
            Float(-0.123456),
        ]
    )
    func orZeroWithNonNil(input: Float) async throws {
        let optionalFloat: Float? = input
        #expect(optionalFloat.orZero == input, "Non-nil float should return original value")
    }

    @Test("Given special float values when getting orZero then handles correctly")
    func orZeroWithSpecialValues() async throws {
        // Infinity
        let infinity: Float? = Float.infinity
        #expect(infinity.orZero == Float.infinity, "Infinity should return infinity")

        let negativeInfinity: Float? = -Float.infinity
        #expect(negativeInfinity.orZero == -Float.infinity, "Negative infinity should return negative infinity")

        // NaN
        let nan: Float? = Float.nan
        #expect(nan.orZero.isNaN, "NaN should return NaN")
    }
}
