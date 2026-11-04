@testable import HomeAssistant
import Testing

struct ManageStorageItemIDTests {
    @Test func everyItemDescribesItselfToTheUser() {
        for id in ManageStorageItemID.allCases {
            #expect(!id.title.isEmpty, "missing title for \(id.rawValue)")
            #expect(!id.explanation.isEmpty, "missing explanation for \(id.rawValue)")
            #expect(id.id == id.rawValue)
        }
    }

    @Test func itemTitlesAndExplanationsAreUnique() {
        let titles = Set(ManageStorageItemID.allCases.map(\.title))
        let explanations = Set(ManageStorageItemID.allCases.map(\.explanation))

        #expect(titles.count == ManageStorageItemID.allCases.count)
        #expect(explanations.count == ManageStorageItemID.allCases.count)
    }
}
