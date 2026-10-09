@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// The icon color on the customization screen is either "Default", which leaves the entity the color
/// the frontend gives it for its state, or "Custom", which fixes it to the color picked below.
struct MagicItemCustomizationViewModelTests {
    private func viewModel(customization: MagicItem.Customization = .init()) -> MagicItemCustomizationViewModel {
        .init(item: .init(id: "light.kitchen", serverId: "1", type: .entity, customization: customization))
    }

    @Test func anItemWithoutAPickedColorIsOnDefault() {
        let viewModel = viewModel()

        #expect(viewModel.usesCustomIconColor == false)
    }

    /// The tint the app wrote into older items on its own was never a choice.
    @Test func anItemSeededWithTheFormerTintIsOnDefault() {
        let viewModel = viewModel(customization: .init(iconColor: "00AEF8"))

        #expect(viewModel.usesCustomIconColor == false)
    }

    @Test func choosingCustomStartsFromTheAppTint() {
        let viewModel = viewModel()

        viewModel.usesCustomIconColor = true

        #expect(viewModel.usesCustomIconColor)
        #expect(viewModel.item.customization?.iconColor == MagicItem.defaultIconColorHex)
        #expect(viewModel.item.customization?.iconColorIsCustomized == true)
        #expect(viewModel.customIconColor.hex() == Color(hex: MagicItem.defaultIconColorHex).hex())
    }

    @Test func pickingAColorFixesTheIconToIt() {
        let viewModel = viewModel()
        viewModel.usesCustomIconColor = true

        viewModel.customIconColor = Color(hex: "#FF9800")

        #expect(viewModel.item.customization?.customIconColor == "FF9800")
        #expect(viewModel.customIconColor.hex() == "FF9800")
    }

    @Test func choosingDefaultDropsThePickedColor() {
        let viewModel = viewModel(customization: .init(iconColor: "#FF9800", iconColorIsCustomized: true))

        viewModel.usesCustomIconColor = false

        #expect(viewModel.usesCustomIconColor == false)
        #expect(viewModel.item.customization?.iconColor == nil)
        #expect(viewModel.item.customization?.iconColorIsCustomized == false)
    }
}
