@testable import HomeAssistant
@testable import Shared
import Testing

struct SettingsSearchIndexTests {
    @Test("Every settings entry belongs to exactly one objective group")
    func sectionsCoverAllItems() {
        let grouped = SettingsSection.allCases.flatMap(\.allItems)
        // Servers and What's New are rendered outside the objective groups.
        let expected = SettingsItem.allCases.filter { $0 != .servers && $0 != .whatsNew }
        #expect(Set(grouped).count == grouped.count)
        #expect(Set(grouped) == Set(expected))
    }

    @Test("Every indexed entry has search keywords")
    func allItemsHaveKeywords() {
        for item in SettingsItem.allCases where item != .whatsNew {
            #expect(!item.searchKeywords.isEmpty, "\(item.rawValue) has no search keywords")
        }
    }

    @Test("Entries match their own title")
    func matchesTitle() {
        for item in SettingsItem.allCases {
            #expect(item.matches(searchQuery: item.title))
        }
    }

    @Test("Entries match localized keywords, not unrelated queries")
    func matchesKeywords() {
        #expect(SettingsItem.location.matches(searchQuery: "gps"))
        #expect(SettingsItem.notifications.matches(searchQuery: "push"))
        #expect(!SettingsItem.location.matches(searchQuery: "watch face"))
    }

    @Test("Matching is case insensitive")
    func matchingIsCaseInsensitive() {
        #expect(SettingsItem.location.matches(searchQuery: "GPS"))
    }

    @Test("Blank queries match everything")
    func emptyQueryMatches() {
        #expect(SettingsItem.general.matches(searchQuery: "  "))
    }
}
