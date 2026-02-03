import Foundation
@testable import Shared
import Testing

@Suite("Dictionary+Additions Extensions Tests")
struct DictionaryExtensionsTests {
    // MARK: - mapKeys Tests

    @Test("Given dictionary with string keys when mapping to uppercase then transforms all keys")
    func mapKeysTransformsAllKeys() {
        let dict = ["hello": 1, "world": 2, "test": 3]
        let result = dict.mapKeys { $0.uppercased() }

        #expect(result["HELLO"] == 1, "Should map 'hello' to 'HELLO'")
        #expect(result["WORLD"] == 2, "Should map 'world' to 'WORLD'")
        #expect(result["TEST"] == 3, "Should map 'test' to 'TEST'")
        #expect(result.count == 3, "Should preserve all entries")
    }

    @Test("Given dictionary when mapping keys to different type then changes key type")
    func mapKeysChangesKeyType() {
        let dict = ["1": "one", "2": "two", "3": "three"]
        let result = dict.mapKeys { Int($0) ?? 0 }

        #expect(result[1] == "one", "Should map '1' to 1")
        #expect(result[2] == "two", "Should map '2' to 2")
        #expect(result[3] == "three", "Should map '3' to 3")
        #expect(result.count == 3, "Should preserve all entries")
    }

    @Test("Given dictionary with duplicate mapped keys when mapping then last value wins")
    func mapKeysWithDuplicateKeysLastValueWins() {
        let dict = ["hello": 1, "HELLO": 2, "HeLLo": 3]
        let result = dict.mapKeys { $0.uppercased() }

        // Since all keys map to "HELLO", one of the values will be present
        #expect(result["HELLO"] != nil, "Should have 'HELLO' key")
        #expect(result.count == 1, "Should have only one entry due to duplicate keys")
        #expect([1, 2, 3].contains(result["HELLO"]!), "Value should be one of the original values")
    }

    // MARK: - compactMapKeys Tests

    @Test("Given dictionary when compact mapping keys then filters out nil results")
    func compactMapKeysFiltersNilResults() {
        let dict = ["1": "one", "2": "two", "invalid": "three", "3": "four"]
        let result = dict.compactMapKeys { Int($0) }

        #expect(result[1] == "one", "Should map '1' to 1")
        #expect(result[2] == "two", "Should map '2' to 2")
        #expect(result[3] == "four", "Should map '3' to 3")
        #expect(result.count == 3, "Should exclude 'invalid' key")
    }

    @Test("Given dictionary when all keys map to nil then returns empty dictionary")
    func compactMapKeysAllNilReturnsEmpty() {
        let dict = ["a": 1, "b": 2, "c": 3]
        let result = dict.compactMapKeys { _ -> Int? in nil }

        #expect(result.isEmpty, "Should return empty dictionary when all keys map to nil")
        #expect(result.count == 0, "Count should be 0")
    }

    @Test("Given dictionary with mixed valid and invalid keys when compact mapping then keeps only valid")
    func compactMapKeysMixedValidInvalid() {
        let dict = [
            "user_1": "Alice",
            "user_2": "Bob",
            "admin": "Charlie",
            "user_3": "Dave",
            "guest": "Eve",
        ]
        let result = dict.compactMapKeys { key -> Int? in
            guard key.hasPrefix("user_") else { return nil }
            return Int(key.replacingOccurrences(of: "user_", with: ""))
        }

        #expect(result.count == 3, "Should only keep user_ keys")
        #expect(result[1] == "Alice", "Should map user_1")
        #expect(result[2] == "Bob", "Should map user_2")
        #expect(result[3] == "Dave", "Should map user_3")
        #expect(result[4] == nil, "Should not include admin")
        #expect(result[5] == nil, "Should not include guest")
    }

    @Test("Given dictionary with duplicate mapped keys when compact mapping then last value wins")
    func compactMapKeysWithDuplicatesLastValueWins() {
        let dict = ["a1": 1, "a2": 2, "b1": 3]
        let result = dict.compactMapKeys { key -> String? in
            String(key.first!)
        }

        #expect(result.count == 2, "Should have 'a' and 'b' keys")
        #expect(result["a"] != nil, "Should have 'a' key")
        #expect(result["b"] == 3, "Should have 'b' key with value 3")
        #expect([1, 2].contains(result["a"]!), "Value for 'a' should be one of the duplicates")
    }
}
