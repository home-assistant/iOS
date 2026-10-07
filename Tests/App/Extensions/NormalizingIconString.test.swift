@testable import Shared
import Testing

struct NormalizingIconStringTests {
    @Test("Strips every prefix the frontend treats as Material Design Icons")
    func stripsMaterialDesignIconPrefixes() {
        #expect("mdi:cog".normalizingIconString == "cog")
        #expect("hass:cog".normalizingIconString == "cog")
        #expect("hassio:cog".normalizingIconString == "cog")
        #expect("hademo:cog".normalizingIconString == "cog")
    }

    @Test("Keeps a foreign prefix, so it cannot be mistaken for an icon name")
    func keepsForeignPrefixes() {
        #expect("hacs:hacs".normalizingIconString == "hacs_hacs")
        #expect("phu:hue-bulb".normalizingIconString == "phu_hue_bulb")
    }

    @Test("Separators become underscores and a name without a prefix is left alone")
    func normalizesSeparators() {
        #expect("mdi:account-box-outline".normalizingIconString == "account_box_outline")
        #expect("zigbee".normalizingIconString == "zigbee")
    }
}
