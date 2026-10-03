import Foundation
@testable import Shared
import Testing

/// An item's icon keeps a fixed color only when the user chose one; otherwise it takes the color
/// home-assistant/frontend gives the entity for its state. These cover how a stored color is told
/// apart from one the app wrote on its own.
struct MagicItemCustomIconColorTests {
    /// "Custom" is an explicit choice, so it holds even for the app's own tint.
    @Test func aCustomColorIsKeptEvenWhenItIsTheAppTint() {
        var customization = MagicItem.Customization()
        customization.useCustomIconColor(MagicItem.defaultIconColorHex)

        #expect(customization.customIconColor == MagicItem.defaultIconColorHex)
        #expect(customization.iconColorIsCustomized == true)
    }

    /// "Default" clears the color itself, so nothing is left for a later read to mistake for a choice.
    @Test func defaultDropsAPickedColor() {
        var customization = MagicItem.Customization()
        customization.useCustomIconColor("#FF0000")
        customization.useDefaultIconColor()

        #expect(customization.iconColor == nil)
        #expect(customization.iconColorIsCustomized == false)
        #expect(customization.customIconColor == nil)
    }

    /// Older versions of the customization screen wrote the app's tint into the item just by
    /// opening, and the tint was `#00AEF8` until September 2025. Neither counts as a choice, whichever
    /// shape the hex was written in.
    @Test(arguments: [
        MagicItem.defaultIconColorHex,
        "00AEF8",
        "#00AEF8",
        "#00aef8",
        "00AEF8FF",
    ])
    func aTintTheAppSeededIsNotAChoice(hex: String) throws {
        let decoded = try decodedCustomization(iconColor: hex)

        #expect(decoded.customIconColor == nil)
    }

    /// Any other color saved before the flag existed was picked by the user.
    @Test func anyOtherColorSavedWithoutTheFlagWasPicked() throws {
        let decoded = try decodedCustomization(iconColor: "#FF9800")

        #expect(decoded.customIconColor == "#FF9800")
    }

    /// The watch's own editor stored picked colors without setting the flag, on items created with it
    /// off, so an unset flag can't be read as "Default" on its own.
    @Test func aColorSavedWithTheFlagOffStillCountsUnlessTheAppSeededIt() {
        #expect(MagicItem.Customization(iconColor: "#4CAF50").customIconColor == "#4CAF50")
        #expect(MagicItem.Customization(iconColor: "00AEF8").customIconColor == nil)
    }

    /// Items saved before ``MagicItem/Customization/iconColorIsCustomized`` existed don't carry it.
    private func decodedCustomization(iconColor: String) throws -> MagicItem.Customization {
        let json = "{\"iconColor\": \"\(iconColor)\", \"requiresConfirmation\": false}"
        return try JSONDecoder().decode(MagicItem.Customization.self, from: Data(json.utf8))
    }
}
