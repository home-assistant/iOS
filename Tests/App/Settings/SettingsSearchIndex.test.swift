@testable import HomeAssistant
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

    @Test("Every screen-backed entry provides content search entries")
    func allScreensProvideContentEntries() {
        // Help is an external link and What's New is a modal, so they have no screen content.
        for item in SettingsItem.allCases where ![.help, .whatsNew].contains(item) {
            // Live Activities entries are only available alongside their screen.
            if item == .liveActivities, #unavailable(iOS 17.2) { continue }
            #expect(!item.contentSearchEntries.isEmpty, "\(item.rawValue) has no content search entries")
        }
    }

    @Test("Screen content matches produce a subtitle")
    func contentMatchesProduceSubtitle() {
        // "Page zoom" is a row inside the General screen.
        let subtitle = SettingsItem.general.contentMatchesSubtitle(searchQuery: "zoom")
        #expect(subtitle?.localizedStandardContains("zoom") == true)
        #expect(SettingsItem.general.matches(searchQuery: "zoom"))
    }

    @Test("Queries matching only the item title produce no subtitle")
    func titleOnlyMatchHasNoSubtitle() {
        #expect(SettingsItem.privacy.contentMatchesSubtitle(searchQuery: "privacy") == nil)
        #expect(SettingsItem.privacy.matches(searchQuery: "privacy"))
    }

    @Test("Subtitle lists at most three matched rows")
    func subtitleCapsMatchedRows() {
        for item in SettingsItem.allCases {
            if let subtitle = item.contentMatchesSubtitle(searchQuery: "e") {
                #expect(subtitle.components(separatedBy: ", ").count <= 3)
            }
        }
    }
}
