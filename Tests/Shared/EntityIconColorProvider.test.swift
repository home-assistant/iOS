import HADesignSystem
@testable import Shared
import SwiftUI
import Testing
import UIKit

struct EntityIconColorProviderTests {
    private func color(
        domain: String,
        deviceClass: String? = nil,
        state: String,
        rgb: [Int]? = nil,
        hs: [Double]? = nil,
        groupMemberDomain: String? = nil
    ) -> Color {
        EntityIconColorProvider.iconColor(
            domain: domain,
            deviceClass: deviceClass,
            state: state,
            liveColor: EntityIconColorProvider.liveColor(
                domain: domain,
                rgbColor: rgb,
                hsColor: hs
            ),
            groupMemberDomain: groupMemberDomain
        )
    }

    // MARK: - Domain defaults

    @Test func domainDefaultsMatchFrontendPalette() throws {
        // Pinned to `color.globals.ts` in home-assistant/frontend — the source of truth.
        try expectColor(color(domain: "light", state: "on"), isHex: "#FFC107") // --state-light-active-color
        try expectColor(color(domain: "switch", state: "on"), isHex: "#FFC107") // --state-switch-active-color
        try expectColor(color(domain: "fan", state: "on"), isHex: "#00BCD4") // --state-fan-active-color
        try expectColor(color(domain: "cover", state: "open"), isHex: "#926BC7") // --state-cover-active-color
        try expectColor(color(domain: "vacuum", state: "cleaning"), isHex: "#009688") // --state-vacuum-active-color
        try expectColor(color(domain: "valve", state: "open"), isHex: "#2196F3") // --state-valve-active-color
        try expectColor(color(domain: "siren", state: "on"), isHex: "#F44336") // --state-siren-active-color
        try expectColor(color(domain: "media_player", state: "playing"), isHex: "#03A9F4")
        // A domain with no accent of its own falls through to --state-active-color.
        try expectColor(color(domain: "input_boolean", state: "on"), isHex: "#FFC107")
    }

    @Test func perStateColorsBeatTheDomainAccent() throws {
        try expectColor(color(domain: "lock", state: "locked"), isHex: "#4CAF50")
        try expectColor(color(domain: "lock", state: "unlocked"), isHex: "#F44336")
        try expectColor(color(domain: "lock", state: "jammed"), isHex: "#F44336")
        try expectColor(color(domain: "lock", state: "locking"), isHex: "#FF9800")
        try expectColor(color(domain: "lock", state: "unlocking"), isHex: "#FF9800")
        try expectColor(color(domain: "climate", state: "heat"), isHex: "#FF6F22")
        try expectColor(color(domain: "climate", state: "cool"), isHex: "#2196F3")
        try expectColor(color(domain: "sun", state: "below_horizon"), isHex: "#3F51B5")
        try expectColor(color(domain: "weather", state: "sunny"), isHex: "#FFC107")
        try expectColor(color(domain: "weather", state: "snowy"), isHex: "#C0E0FF")
        try expectColor(color(domain: "person", state: "home"), isHex: "#4CAF50")
        try expectColor(color(domain: "alarm_control_panel", state: "triggered"), isHex: "#F44336")
        try expectColor(color(domain: "alarm_control_panel", state: "armed_away"), isHex: "#4CAF50")
    }

    // MARK: - Device class defaults

    @Test func deviceClassBeatsTheDomainDefault() throws {
        // --state-binary_sensor-gas-on-color, rather than --state-binary_sensor-active-color.
        try expectColor(color(domain: "binary_sensor", deviceClass: "gas", state: "on"), isHex: "#F44336")
        try expectColor(color(domain: "binary_sensor", deviceClass: "smoke", state: "on"), isHex: "#F44336")
        try expectColor(color(domain: "binary_sensor", deviceClass: "moisture", state: "on"), isHex: "#F44336")
        // A device class with no color of its own keeps the domain default.
        try expectColor(color(domain: "binary_sensor", deviceClass: "motion", state: "on"), isHex: "#FFC107")
        // …and an off binary sensor is inactive whatever its device class is.
        try expectColor(color(domain: "binary_sensor", deviceClass: "gas", state: "off"), isHex: "#9E9E9E")
    }

    @Test func batterySensorsAreColoredByLevel() throws {
        try expectColor(color(domain: "sensor", deviceClass: "battery", state: "95"), isHex: "#4CAF50")
        try expectColor(color(domain: "sensor", deviceClass: "battery", state: "50"), isHex: "#FF9800")
        try expectColor(color(domain: "sensor", deviceClass: "battery", state: "12"), isHex: "#F44336")
        // A non-numeric battery state has no level to color from, and `sensor` takes no state color.
        try expectColor(color(domain: "sensor", deviceClass: "battery", state: "charging"), isHex: "#44739E")
    }

    // MARK: - Neutral defaults

    @Test func domainsWithoutStateColorsUseTheNeutralDefaults() throws {
        // --state-icon-color while active, --state-inactive-color otherwise.
        try expectColor(color(domain: "sensor", state: "21.5"), isHex: "#44739E")
        try expectColor(color(domain: "number", state: "3"), isHex: "#44739E")
        try expectColor(color(domain: "sensor", state: "unknown"), isHex: "#9E9E9E")
    }

    @Test func inactiveStatesUseTheInactiveColor() throws {
        try expectColor(color(domain: "light", state: "off"), isHex: "#9E9E9E")
        try expectColor(color(domain: "switch", state: "off"), isHex: "#9E9E9E")
        try expectColor(color(domain: "cover", state: "closed"), isHex: "#9E9E9E")
        try expectColor(color(domain: "person", state: "not_home"), isHex: "#9E9E9E")
    }

    @Test func unavailableUsesTheUnavailableColor() throws {
        try expectColor(color(domain: "light", state: "unavailable"), isHex: "#BDBDBD")
        try expectColor(color(domain: "lock", state: "unavailable"), isHex: "#BDBDBD")
    }

    // MARK: - Groups

    @Test func groupsBorrowTheirMembersDomainPalette() throws {
        try expectColor(color(domain: "group", state: "on", groupMemberDomain: "fan"), isHex: "#00BCD4")
        // A mixed group has no single member domain, so it keeps the generic active color.
        try expectColor(color(domain: "group", state: "on"), isHex: "#FFC107")
        try expectColor(color(domain: "group", state: "off", groupMemberDomain: "fan"), isHex: "#9E9E9E")
    }

    @Test func groupMemberDomainIsTheOneEveryMemberShares() {
        #expect(EntityIconColorProvider.groupMemberDomain(
            attributes: ["entity_id": ["light.a", "light.b"]]
        ) == "light")
        #expect(EntityIconColorProvider.groupMemberDomain(
            attributes: ["entity_id": ["light.a", "switch.b"]]
        ) == nil)
        #expect(EntityIconColorProvider.groupMemberDomain(attributes: [:]) == nil)
    }

    // MARK: - Live light color

    @Test func liveColorWinsWhenTheLightIsOn() throws {
        try expectColor(color(domain: "light", state: "on", rgb: [255, 140, 0]), isHex: "#FF8C00")
    }

    @Test func liveColorIsContrastAdjusted() throws {
        // A white light would be invisible on the tile, so the frontend dims it to v = 225.
        try expectColor(
            color(domain: "light", state: "on", rgb: [255, 255, 255]),
            isHex: "#E1E1E1"
        )
        // A barely saturated color is pushed to 40% saturation instead.
        try expectColor(
            color(domain: "light", state: "on", rgb: [255, 200, 200]),
            isHex: "#FF9999"
        )
        // Under 10% saturation it is dimmed rather than saturated, like the white case.
        try expectColor(
            color(domain: "light", state: "on", rgb: [255, 235, 235]),
            isHex: "#E1CFCF"
        )
    }

    @Test func liveColorIsIgnoredOffAndOutsideLights() throws {
        try expectColor(color(domain: "light", state: "off", rgb: [255, 140, 0]), isHex: "#9E9E9E")
        #expect(EntityIconColorProvider.liveColor(domain: "switch", rgbColor: [255, 140, 0], hsColor: nil) == nil)
        #expect(EntityIconColorProvider.liveColor(domain: "light", rgbColor: nil, hsColor: nil) == nil)
    }

    // MARK: - User override

    @Test func aPickedColorOnlyAppliesWhileActive() throws {
        let picked = Color(hex: "#FF00FF")
        try expectColor(
            EntityIconColorProvider.iconColor(domain: "light", state: "on", customColor: picked),
            isHex: "#FF00FF"
        )
        // Off, the tile reads as off rather than as the picked color, as the tile card does.
        try expectColor(
            EntityIconColorProvider.iconColor(domain: "light", state: "off", customColor: picked),
            isHex: "#9E9E9E"
        )
        // …and it beats a light's own color while on.
        try expectColor(
            EntityIconColorProvider.iconColor(
                domain: "light",
                state: "on",
                liveColor: Color(hex: "#FF8C00"),
                customColor: picked
            ),
            isHex: "#FF00FF"
        )
    }

    // MARK: - Active state

    @Test func activeStateFollowsTheFrontendRules() {
        #expect(EntityStateActive.isActive(domain: "light", state: "on"))
        #expect(!EntityStateActive.isActive(domain: "light", state: "off"))
        #expect(!EntityStateActive.isActive(domain: "lock", state: "locked"))
        #expect(EntityStateActive.isActive(domain: "lock", state: "unlocked"))
        #expect(!EntityStateActive.isActive(domain: "cover", state: "closed"))
        #expect(!EntityStateActive.isActive(domain: "alarm_control_panel", state: "disarmed"))
        #expect(!EntityStateActive.isActive(domain: "vacuum", state: "docked"))
        #expect(!EntityStateActive.isActive(domain: "person", state: "not_home"))
        #expect(EntityStateActive.isActive(domain: "plant", state: "problem"))
        #expect(!EntityStateActive.isActive(domain: "plant", state: "ok"))
        // "off" is still an active alert; "idle" is the one that isn't.
        #expect(EntityStateActive.isActive(domain: "alert", state: "off"))
        #expect(!EntityStateActive.isActive(domain: "alert", state: "idle"))
        // Timestamp-state domains are active as long as they're available.
        #expect(EntityStateActive.isActive(domain: "scene", state: "2024-01-01T00:00:00+00:00"))
        #expect(!EntityStateActive.isActive(domain: "scene", state: "unavailable"))
    }

    // MARK: - Helpers

    private func expectColor(
        _ color: Color,
        isHex hex: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let reference = try #require(UIColor(rgbaString: hex))
        let resolved = UIColor(color).resolvedColor(with: .init(userInterfaceStyle: .light))
        for (actual, wanted) in zip(rgba(resolved), rgba(reference)) {
            #expect(abs(actual - wanted) < 0.004, "Expected \(hex), got \(resolved)", sourceLocation: sourceLocation)
        }
    }

    private func rgba(_ color: UIColor) -> [CGFloat] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }
}
