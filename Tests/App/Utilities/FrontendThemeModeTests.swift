@testable import HomeAssistant
import Testing
import UIKit

struct FrontendThemeModeTests {
    @Test func readsTheDarkFlagTheFrontendStoresForTheAccount() {
        #expect(FrontendThemeMode(userDataValue: ["theme": "default", "dark": true]) == .dark)
        #expect(FrontendThemeMode(userDataValue: ["theme": "default", "dark": false]) == .light)
    }

    @Test func aUserWhoNeverPickedAModeFollowsTheDevice() {
        // "Auto" writes no `dark` key at all, and a user who never opened the picker has no value.
        #expect(FrontendThemeMode(userDataValue: ["theme": "default"]) == .automatic)
        #expect(FrontendThemeMode(userDataValue: [:]) == .automatic)
        #expect(FrontendThemeMode(userDataValue: nil) == .automatic)
        #expect(FrontendThemeMode(userDataValue: NSNull()) == .automatic)
    }

    @Test func aPayloadWeDoNotRecogniseFollowsTheDeviceRatherThanGuessing() {
        #expect(FrontendThemeMode(userDataValue: "dark") == .automatic)
        #expect(FrontendThemeMode(userDataValue: ["dark": "true"]) == .automatic)
    }

    @Test func onlyAnExplicitChoiceOverridesTheDevice() {
        #expect(FrontendThemeMode.automatic.userInterfaceStyle == .unspecified)
        #expect(FrontendThemeMode.light.userInterfaceStyle == .light)
        #expect(FrontendThemeMode.dark.userInterfaceStyle == .dark)
    }
}
