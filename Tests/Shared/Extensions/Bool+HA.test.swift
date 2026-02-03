import Foundation
@testable import Shared
import Testing

@Suite("Bool+HA Extensions Tests")
struct BoolHAExtensionsTests {
    // MARK: - Bool? orFalse Tests

    @Test("Given nil bool when getting orFalse then returns false")
    func orFalseWithNil() async throws {
        let nilBool: Bool? = nil
        #expect(nilBool.orFalse == false, "nil bool should return false")
    }

    @Test("Given true bool when getting orFalse then returns true")
    func orFalseWithTrue() async throws {
        let trueBool: Bool? = true
        #expect(trueBool.orFalse == true, "true bool should return true")
    }

    @Test("Given false bool when getting orFalse then returns false")
    func orFalseWithFalse() async throws {
        let falseBool: Bool? = false
        #expect(falseBool.orFalse == false, "false bool should return false")
    }
}
