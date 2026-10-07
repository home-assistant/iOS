@testable import HomeAssistant
import Testing

struct AppConfigurationCategoryTests {
    @Test func everyCategoryDescribesItselfToTheUser() {
        for category in AppConfigurationCategory.allCases {
            #expect(!category.title.isEmpty, "missing title for \(category.rawValue)")
            #expect(!category.explanation.isEmpty, "missing explanation for \(category.rawValue)")
        }
    }

    @Test func categoryTitlesAreUnique() {
        let titles = Set(AppConfigurationCategory.allCases.map(\.title))

        #expect(titles.count == AppConfigurationCategory.allCases.count)
    }

    @Test func onlySingleRecordCategoriesAreMarkedAsSingleValue() {
        let singleValue = AppConfigurationCategory.allCases.filter(\.isSingleValue)

        #expect(Set(singleValue) == [.appSettings, .kiosk])
    }
}
