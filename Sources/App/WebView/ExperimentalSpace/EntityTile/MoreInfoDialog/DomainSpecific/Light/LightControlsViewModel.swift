import AppIntents
import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class LightControlsViewModel {
    enum ColorMode {
        case color
        case temperature
    }

    // MARK: - Published State

    var brightness: Double = 0
    var selectedColor: Color = .white
    var pickerColor: Color = .white
    var isOn: Bool = false
    var iconColor: Color = .secondary
    var colorTemperature: Double = 250 // mireds
    var currentColorMode: ColorMode = .color
    var minMireds: Double = LightControlsView.Constants.minMireds
    var maxMireds: Double = LightControlsView.Constants.maxMireds
    var recentColors: [StoredColor] = []
    var recentTemperatures: [Double] = []
    var hasInitialized: Bool = false

    // MARK: - Dependencies

    private let server: Server
    private var haEntity: HAEntity

    // MARK: - Initialization

    init(server: Server, haEntity: HAEntity) {
        self.server = server
        self.haEntity = haEntity
    }

    // MARK: - Public Methods

    func updateEntity(_ haEntity: HAEntity) {
        self.haEntity = haEntity
        updateStateFromEntity()
    }

    func initialize() {
        updateStateFromEntity()
        pickerColor = selectedColor
        hasInitialized = true
    }

    func stateDescription() -> String {
        Domain(entityId: haEntity.entityId)?.contextualStateDescription(for: haEntity) ?? haEntity.state
    }

    // MARK: - State Management

    func updateStateFromEntity() {
        updateBasicState(from: haEntity)
        updateTemperatureState(from: haEntity)
        updateColorMode(from: haEntity)
        updateColors(from: haEntity)
    }

    private func updateBasicState(from haEntity: HAEntity) {
        isOn = haEntity.state == "on"

        if let brightnessValue = haEntity.attributes["brightness"] as? Int {
            brightness = Double(brightnessValue) / 255.0 * 100.0
        } else {
            brightness = isOn ? 100 : 0
        }
    }

    private func updateTemperatureState(from haEntity: HAEntity) {
        // Update color temperature if available
        if let colorTemp = haEntity.attributes["color_temp"] as? Int {
            colorTemperature = Double(colorTemp)
        }

        // Update temperature range if provided by the entity
        if let minMiredsValue = haEntity.attributes["min_mireds"] as? Int {
            minMireds = Double(minMiredsValue)
        }
        if let maxMiredsValue = haEntity.attributes["max_mireds"] as? Int {
            maxMireds = Double(maxMiredsValue)
        }
    }

    private func updateColorMode(from haEntity: HAEntity) {
        guard let colorMode = haEntity.attributes["color_mode"] as? String else {
            // If no color_mode specified, default based on what's supported
            currentColorMode = supportsColor() ? .color : (supportsColorTemp() ? .temperature : .color)
            return
        }

        // Determine current mode based on color_mode from server
        if colorMode == "color_temp", supportsColorTemp() {
            currentColorMode = .temperature
        } else if ["rgb", "rgbw", "rgbww", "hs", "xy"].contains(colorMode), supportsColor() {
            currentColorMode = .color
        }
    }

    private func updateColors(from haEntity: HAEntity) {
        let colorMode = haEntity.attributes["color_mode"] as? String
        let rgbColor = haEntity.attributes["rgb_color"] as? [Int]
        let hsColor = haEntity.attributes["hs_color"] as? [Double]

        // Update icon color using the same logic as EntityTileView
        let newIconColor = EntityIconColorProvider.iconColor(
            state: haEntity.state,
            colorMode: colorMode,
            rgbColor: rgbColor,
            hsColor: hsColor
        )
        if !colorsAreEqual(newIconColor, iconColor) {
            iconColor = newIconColor
        }

        // Update selected color for the UI controls only if it changed
        updateSelectedColor(rgbColor: rgbColor, hsColor: hsColor, fallbackColor: newIconColor)
    }

    private func updateSelectedColor(rgbColor: [Int]?, hsColor: [Double]?, fallbackColor: Color) {
        if let rgbColor, rgbColor.count == 3 {
            let newColor = Color(
                red: Double(rgbColor[0]) / 255.0,
                green: Double(rgbColor[1]) / 255.0,
                blue: Double(rgbColor[2]) / 255.0
            )
            if !colorsAreEqual(newColor, selectedColor) {
                selectedColor = newColor
            }
        } else if let hsColor, hsColor.count == 2 {
            let hue = hsColor[0] / 360.0
            let saturation = hsColor[1] / 100.0
            let newColor = Color(hue: hue, saturation: saturation, brightness: 1.0)
            if !colorsAreEqual(newColor, selectedColor) {
                selectedColor = newColor
            }
        } else {
            if !colorsAreEqual(fallbackColor, selectedColor) {
                selectedColor = fallbackColor
            }
        }
    }

    // MARK: - Support Checks

    func supportsBrightness() -> Bool {
        // Check supported_color_modes for brightness-capable modes
        if let supportedColorModes = haEntity.attributes["supported_color_modes"] as? [String] {
            // All color modes except "onoff" support brightness
            return !supportedColorModes.isEmpty && !supportedColorModes.allSatisfy { $0 == "onoff" }
        }

        // Fallback: check if brightness attribute exists when light is on
        if haEntity.state == "on", haEntity.attributes["brightness"] != nil {
            return true
        }

        return false
    }

    func supportsColor() -> Bool {
        if let supportedColorModes = haEntity.attributes["supported_color_modes"] as? [String] {
            return supportedColorModes.contains(where: { mode in
                ["rgb", "rgbw", "rgbww", "hs", "xy"].contains(mode)
            })
        }
        return false
    }

    func supportsColorTemp() -> Bool {
        if let supportedColorModes = haEntity.attributes["supported_color_modes"] as? [String] {
            return supportedColorModes.contains("color_temp")
        }
        return false
    }

    private func colorsAreEqual(_ lhs: Color, _ rhs: Color, tolerance: CGFloat = 0.01) -> Bool {
        let l = UIColor(lhs)
        let r = UIColor(rhs)
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        l.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        r.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        return abs(lr - rr) <= tolerance && abs(lg - rg) <= tolerance && abs(lb - rb) <= tolerance && abs(la - ra) <=
            tolerance
    }

    // MARK: - Service Calls

    func toggleLight() async {
        let intent = ToggleLightIntent()
        intent.light = createLightEntity()
        intent.turnOn = !isOn

        do {
            _ = try await intent.perform()
            // Update local state
            isOn = !isOn
            if !isOn {
                brightness = 0
                iconColor = .secondary
            }
        } catch {
            Current.Log.verbose("Failed to toggle light: \(error)")
        }
    }

    func updateBrightness(_ value: Double) async {
        // If light is off and brightness is increased, turn it on
        if !isOn, value > 0 {
            let turnOnIntent = ToggleLightIntent()
            turnOnIntent.light = createLightEntity()
            turnOnIntent.turnOn = true

            do {
                _ = try await turnOnIntent.perform()
                isOn = true
            } catch {
                Current.Log.verbose("Failed to turn on light: \(error)")
                return
            }
        }

        guard isOn else { return }

        let intent = SetLightBrightnessIntent()
        intent.light = createLightEntity()
        intent.brightness = Int(value / 100.0 * 255.0)

        do {
            _ = try await intent.perform()
            brightness = value
        } catch {
            Current.Log.verbose("Failed to update brightness: \(error)")
        }
    }

    func updateColor(_ color: Color, saveToRecents: Bool = false) async {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgbColor = [Int(red * 255), Int(green * 255), Int(blue * 255)]

        let intent = SetLightColorIntent()
        intent.light = createLightEntity()
        intent.rgbColor = rgbColor

        do {
            _ = try await intent.perform()
            // Update local state
            selectedColor = color
            iconColor = color

            // Only save to recents if explicitly requested (user interaction)
            if saveToRecents {
                await saveColorToRecents(color)
            }
        } catch {
            Current.Log.verbose("Failed to update color: \(error)")
        }
    }

    func updateColorTemperature(_ mireds: Double) async {
        let intent = SetLightColorTemperatureIntent()
        intent.light = createLightEntity()
        intent.colorTemp = Int(mireds)

        do {
            _ = try await intent.perform()
            colorTemperature = mireds

            // Update icon color to approximate white tone
            iconColor = colorFromTemperature(mireds)

            // Save to recent temperatures
            await saveTemperatureToRecents(mireds)
        } catch {
            Current.Log.verbose("Failed to update color temperature: \(error)")
        }
    }

    func colorFromTemperature(_ mireds: Double) -> Color {
        // Approximate color based on temperature
        let kelvin = 1_000_000 / mireds

        if kelvin < 3000 {
            // Warm white (yellowish)
            return Color(red: 1.0, green: 0.8, blue: 0.6)
        } else if kelvin < 5000 {
            // Neutral white
            return Color(red: 1.0, green: 0.95, blue: 0.9)
        } else {
            // Cool white (bluish)
            return Color(red: 0.9, green: 0.95, blue: 1.0)
        }
    }

    func kelvinFromMireds(_ mireds: Double) -> Int {
        Int(1_000_000 / mireds)
    }

    // MARK: - Intent Helpers

    private func createLightEntity() -> IntentLightEntity {
        IntentLightEntity(
            id: haEntity.entityId,
            entityId: haEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: haEntity.attributes.friendlyName ?? haEntity.entityId,
            iconName: haEntity.attributes.icon ?? ""
        )
    }

    // MARK: - Color Persistence

    private var recentColorsCacheKey: String {
        "light.recentColors.\(server.identifier.rawValue).\(haEntity.entityId)"
    }

    private var recentTemperaturesCacheKey: String {
        "light.recentTemperatures.\(server.identifier.rawValue).\(haEntity.entityId)"
    }

    func loadRecentColors() async {
        do {
            let colors: [StoredColor] = try await withCheckedThrowingContinuation { continuation in
                Current.diskCache
                    .value(for: recentColorsCacheKey)
                    .done { (colors: [StoredColor]) in
                        continuation.resume(returning: colors)
                    }
                    .catch { error in
                        continuation.resume(throwing: error)
                    }
            }
            recentColors = colors
        } catch {
            // No cached colors, use empty array (will show defaults)
            recentColors = []
        }
    }

    func loadRecentTemperatures() async {
        do {
            let temperatures: [Double] = try await withCheckedThrowingContinuation { continuation in
                Current.diskCache
                    .value(for: recentTemperaturesCacheKey)
                    .done { (temperatures: [Double]) in
                        continuation.resume(returning: temperatures)
                    }
                    .catch { error in
                        continuation.resume(throwing: error)
                    }
            }
            recentTemperatures = temperatures
        } catch {
            // No cached temperatures, use empty array (will show defaults)
            recentTemperatures = []
        }
    }

    private func saveColorToRecents(_ color: Color) async {
        let storedColor = StoredColor(from: color)

        // If the most recent color matches, skip re-saving
        if let first = recentColors.first, first.isEqual(to: storedColor) {
            return
        }

        // Remove duplicate if it exists
        var updatedColors = recentColors.filter { !$0.isEqual(to: storedColor) }

        // Add the new color to the front
        updatedColors.insert(storedColor, at: 0)

        // Keep only the most recent colors (7 colors, leaving room for color picker in 8th spot)
        let maxRecentColors = LightControlsView.Constants.maxColorPresets - 1
        if updatedColors.count > maxRecentColors {
            updatedColors = Array(updatedColors.prefix(maxRecentColors))
        }

        recentColors = updatedColors

        // Save to disk cache
        Current.diskCache.set(updatedColors, for: recentColorsCacheKey).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save recent colors: \(error)")
            }
        }
    }

    private func saveTemperatureToRecents(_ mireds: Double) async {
        // If the most recent temperature is very similar (within 10 mireds), skip re-saving
        if let first = recentTemperatures.first, abs(first - mireds) < 10 {
            return
        }

        // Remove similar temperatures (within 10 mireds tolerance)
        var updatedTemperatures = recentTemperatures.filter { abs($0 - mireds) >= 10 }

        // Add the new temperature to the front
        updatedTemperatures.insert(mireds, at: 0)

        // Keep only the most recent temperatures
        if updatedTemperatures.count > LightControlsView.Constants.maxTemperaturePresets {
            updatedTemperatures = Array(updatedTemperatures.prefix(LightControlsView.Constants.maxTemperaturePresets))
        }

        recentTemperatures = updatedTemperatures

        // Save to disk cache
        Current.diskCache.set(updatedTemperatures, for: recentTemperaturesCacheKey).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save recent temperatures: \(error)")
            }
        }
    }

    // MARK: - Stored Color Model

    struct StoredColor: Codable, Equatable {
        let red: Double
        let green: Double
        let blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(from color: Color) {
            let uiColor = UIColor(color)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            self.red = Double(r)
            self.green = Double(g)
            self.blue = Double(b)
        }

        func toColor() -> Color {
            Color(red: red, green: green, blue: blue)
        }

        func isEqual(to other: StoredColor) -> Bool {
            // Compare with a small tolerance to account for floating-point precision
            let tolerance = 0.01
            return abs(red - other.red) < tolerance &&
                abs(green - other.green) < tolerance &&
                abs(blue - other.blue) < tolerance
        }
    }
}
