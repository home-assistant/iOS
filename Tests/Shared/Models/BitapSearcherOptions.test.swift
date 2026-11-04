import Foundation
@testable import Shared
import Testing

/// Bitap fuzzy matching beyond the defaults the entity picker uses: long patterns split into chunks,
/// empty patterns, location-aware scoring and the minimum match length.
struct BitapSearcherOptionsTests {
    @Test func identicalTextIsAPerfectMatch() {
        let result = BitapSearcher(pattern: "Kitchen Light", options: .init()).searchIn("kitchen light")
        #expect(result.isMatch)
        #expect(result.score == 0)
    }

    @Test func emptyPatternsNeverMatchOtherText() {
        let result = BitapSearcher(pattern: "", options: .init()).searchIn("anything")
        #expect(!result.isMatch)
        #expect(result.score == 1)
    }

    @Test func longPatternsAreSearchedInChunks() {
        let pattern = "living room ceiling light dimmer switch panel"
        #expect(pattern.count > 32)
        let searcher = BitapSearcher(pattern: pattern, options: .init())
        #expect(searcher.searchIn("the living room ceiling light dimmer switch panel by the door").isMatch)
        #expect(!searcher.searchIn("garage").isMatch)

        let exactMultiple = String(repeating: "abcdefgh", count: 8)
        #expect(BitapSearcher(pattern: exactMultiple, options: .init()).searchIn("xx" + exactMultiple).isMatch)
    }

    @Test func locationAwareScoringPrefersMatchesNearTheExpectedPosition() {
        var options = BitapSearcher.Options()
        options.ignoreLocation = false
        options.location = 0
        options.distance = 10
        let searcher = BitapSearcher(pattern: "lamp", options: options)
        let near = searcher.searchIn("lamp in the hall")
        let far = searcher.searchIn("a very long description that ends with lamp")
        #expect(near.isMatch)
        #expect(!far.isMatch || far.score > near.score)

        options.distance = 0
        let strict = BitapSearcher(pattern: "lamp", options: options)
        #expect(strict.searchIn("lamp").isMatch)
        _ = strict.searchIn("the lamp")
    }

    @Test func findAllMatchesHonoursTheMinimumLength() {
        var options = BitapSearcher.Options()
        options.findAllMatches = true
        options.minMatchCharLength = 3
        let searcher = BitapSearcher(pattern: "fan", options: options)
        #expect(searcher.searchIn("bedroom fan").isMatch)
        #expect(searcher.searchIn("fan in the bedroom").isMatch)
        options.minMatchCharLength = 10
        #expect(!BitapSearcher(pattern: "fan", options: options).searchIn("bedroom fan").isMatch)
    }
}
