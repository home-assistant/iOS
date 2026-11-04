import Foundation
@testable import Shared
import Testing

/// The text color is a property of the complication, not of the size that happened to be selected
/// when it was picked: a color set in the editor has to reach whichever size the complication is
/// actually placed in on the watch face.
struct WatchComplicationConfigTextColorTests {
    private func templateConfig() -> WatchComplicationConfig {
        WatchComplicationConfig(
            serverId: "server",
            kind: .customTemplate,
            name: "Solar",
            customTextTemplate: "{{ tpl }}"
        )
    }

    @Test("The config-wide color applies to every size")
    func configWideColorAppliesEverywhere() {
        var config = templateConfig()
        config.setTextColor("#FF9500FF")
        for family in WatchComplicationConfig.Family.allCases {
            #expect(config.textColor(for: family) == "#FF9500FF")
        }
    }

    @Test("No color anywhere resolves to nil, so rendering falls back to the face default")
    func noColorResolvesToNil() {
        let config = templateConfig()
        #expect(WatchComplicationConfig.Family.allCases.allSatisfy { config.textColor(for: $0) == nil })
    }

    @Test("A per-size override from an older config still wins for its own size")
    func perSizeOverrideWins() {
        var config = templateConfig()
        config.textColor = "#FF9500FF"
        config.setOptions(.init(textColor: "#34C759FF"), for: .circular)
        #expect(config.textColor(for: .circular) == "#34C759FF")
        #expect(config.textColor(for: .corner) == "#FF9500FF")
    }

    @Test("Picking a color clears the per-size overrides that would shadow it")
    func pickingAColorClearsOverrides() {
        var config = templateConfig()
        config.setOptions(.init(tint: "#000000FF", textColor: "#34C759FF"), for: .circular)
        config.setTextColor("#FF9500FF")
        #expect(config.textColor(for: .circular) == "#FF9500FF")
        #expect(config.textColor(for: .corner) == "#FF9500FF")
        // Only the text color is cleared — the size keeps the rest of its customization.
        #expect(config.options(for: .circular).tint == "#000000FF")
    }

    @Test("Clearing the custom colors clears the config-wide text color too")
    func clearCustomColorsClearsTextColor() {
        var config = templateConfig()
        config.setTextColor("#FF9500FF")
        #expect(config.usesCustomColors())
        config.clearCustomColors()
        #expect(!config.usesCustomColors())
        #expect(config.textColor(for: .corner) == nil)
    }

    @Test("The text color round-trips through Codable")
    func codableRoundTrip() throws {
        var config = templateConfig()
        config.setTextColor("#FF9500FF")
        let decoded = try JSONDecoder().decode(
            WatchComplicationConfig.self,
            from: JSONEncoder().encode(config)
        )
        #expect(decoded.textColor == "#FF9500FF")
        #expect(decoded.textColor(for: .corner) == "#FF9500FF")
    }
}
