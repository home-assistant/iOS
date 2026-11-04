@testable import HomeAssistant
import Testing

struct ManageStorageCategoryTests {
    @Test func everyCategoryDescribesItselfToTheUser() {
        for category in ManageStorageCategory.allCases {
            #expect(!category.title.isEmpty, "missing title for \(category.rawValue)")
            #expect(!category.explanation.isEmpty, "missing explanation for \(category.rawValue)")
            #expect(category.id == category.rawValue)
        }
    }

    @Test func categoryTitlesAndIconsAreUnique() {
        let titles = Set(ManageStorageCategory.allCases.map(\.title))
        let icons = Set(ManageStorageCategory.allCases.map(\.icon))

        #expect(titles.count == ManageStorageCategory.allCases.count)
        #expect(icons.count == ManageStorageCategory.allCases.count)
    }

    @Test func categoriesOrderFromEssentialDataToScratchSpace() {
        #expect(ManageStorageCategory.allCases.sorted() == ManageStorageCategory.allCases)
        #expect(ManageStorageCategory.appData < ManageStorageCategory.temporary)
        #expect(!(ManageStorageCategory.temporary < ManageStorageCategory.appData))
        #expect(!(ManageStorageCategory.caches < ManageStorageCategory.caches))
    }
}
