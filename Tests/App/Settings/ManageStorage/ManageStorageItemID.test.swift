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

    @Test func itemTitlesExplanationsAndIconsAreUnique() {
        let titles = Set(ManageStorageItemID.allCases.map(\.title))
        let explanations = Set(ManageStorageItemID.allCases.map(\.explanation))
        let icons = Set(ManageStorageItemID.allCases.map(\.icon))

        #expect(titles.count == ManageStorageItemID.allCases.count)
        #expect(explanations.count == ManageStorageItemID.allCases.count)
        #expect(icons.count == ManageStorageItemID.allCases.count)
    }
}
