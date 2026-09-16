@testable import HomeAssistant
import Testing

struct SettingsSectionLayoutTests {
    @Test("App Labs is the last section and stands on its own")
    func appLabsIsTheLastStandaloneSection() {
        #expect(SettingsSection.allCases.last == .appLabs)
        #expect(SettingsSection.appLabs.allItems == [.appLabs])
        #expect(!SettingsSection.helpSupport.allItems.contains(.appLabs))
    }

    /// The iOS list renders What's New, Beta Tester Updates and About after the objective groups,
    /// so App Labs has to be held back from that batch to end up below them.
    @Test("App Labs is held back from the groups rendered above the trailing rows")
    func appLabsIsNotRenderedWithTheOtherGroups() {
        let groups = SettingsSection.groupsAboveTrailingRows
        #expect(!groups.contains(.appLabs))
        #expect(groups == Array(SettingsSection.allCases.dropLast()))
    }

    @Test("The App Labs section has no header, since its only row names it")
    func appLabsSectionHasNoHeader() {
        #expect(SettingsSection.appLabs.header == nil)
        for section in SettingsSection.allCases where section != .appLabs {
            #expect(section.header?.isEmpty == false, "\(section.rawValue) has no header")
        }
    }

    /// The device lends Home Assistant its speech recognition and synthesis, so the row sits with
    /// the other things shared from this device rather than in App Labs.
    @Test("The voice tools server is shared from this device")
    func voiceToolsServerIsSharedFromThisDevice() {
        #expect(SettingsSection.shareFromDevice.allItems.last == .voiceToolsServer)
        #expect(!SettingsSection.appLabs.allItems.contains(.voiceToolsServer))
    }

    @Test("App Labs is the only entry carrying a static subtitle")
    func appLabsIsTheOnlyEntryWithASubtitle() {
        #expect(SettingsItem.appLabs.subtitle?.isEmpty == false)
        for item in SettingsItem.allCases where item != .appLabs {
            #expect(item.subtitle == nil, "\(item.rawValue) unexpectedly has a subtitle")
        }
    }
}
