import AppIntents
import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct LightControlsView: View {
    enum Constants {
        static let controlHeight: CGFloat = 56
        static let brightnessIconSize: CGFloat = 20
        static let bulbPreviewWidth: CGFloat = 180
        static let bulbPreviewHeight: CGFloat = 360
        static let swatchSize: CGFloat = 44
        static let swatchSpacing: CGFloat = 12
        static let controlBarHeight: CGFloat = 56
        static let controlIconSize: CGFloat = 20
        static let cornerRadius: CGFloat = 28
        static let maxColorPresets: Int = 8
        static let colorPresetsRows: Int = 2
        static let colorPresetsColumns: Int = 4
        // Temperature constants (mireds)
        static let minMireds: Double = 153 // ~6500K (cool white)
        static let maxMireds: Double = 500 // ~2000K (warm white)
    }

    enum ColorMode {
        case color
        case temperature
    }

    let server: Server
    let appEntity: HAAppEntity
    let haEntity: HAEntity?

    @State private var brightness: Double = 0
    @State private var selectedColor: Color = .white
    @State private var pickerColor: Color = .white
    @State private var isOn: Bool = false
    @State private var triggerHaptic = 0
    @State private var iconColor: Color = .secondary
    @State private var colorTemperature: Double = 250 // mireds
    @State private var currentColorMode: ColorMode = .color
    @State private var minMireds: Double = Constants.minMireds
    @State private var maxMireds: Double = Constants.maxMireds

    // UI state
    @State private var showColorPresets: Bool = true
    @State private var recentColors: [StoredColor] = []
    @State private var isUpdatingFromServer: Bool = false
    @State private var hasInitialized: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.two) {
                header
                brightnessSlider
                controlBar

                // Mode toggle if light supports both color and temperature
                if supportsColor(), supportsColorTemp() {
                    modeToggle
                }

                // Show appropriate controls based on mode and support
                if supportsColor(), currentColorMode == .color, showColorPresets {
                    HStack {
                        Spacer()
                        colorPresetsGrid
                        Spacer()
                    }
                }

                if supportsColorTemp(), currentColorMode == .temperature {
                    temperatureSlider
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updateStateFromEntity()
            // Initialize picker color once; it will not be updated by remote changes afterwards
            pickerColor = selectedColor
            // Mark as initialized so future color changes trigger updates
            hasInitialized = true
            Task { await loadRecentColors() }
        }
        .onChange(of: haEntity) { _, _ in updateStateFromEntity() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(stateDescription)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
                .animation(.easeInOut, value: isOn)

            Text("\(Int(brightness))%")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
                .animation(.easeInOut, value: brightness)
        }
    }

    private var stateDescription: String {
        guard let haEntity else { return "Off" }
        return Domain(entityId: appEntity.entityId)?.contextualStateDescription(for: haEntity) ?? haEntity.state
    }

    // MARK: - Bulb Preview

    private var bulbPreview: some View {
        let displayColor = isOn ? iconColor : Color(uiColor: .systemGray5)
        let brightnessOpacity = isOn ? max(0.15, brightness / 100.0) : 1.0

        return RoundedRectangle(cornerRadius: Constants.cornerRadius * 1.2, style: .continuous)
            .fill(displayColor.opacity(isOn ? 0.25 : 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius * 1.2, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .frame(width: Constants.bulbPreviewWidth, height: Constants.bulbPreviewHeight)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 36))
                        .foregroundStyle(isOn ? iconColor : .secondary)
                        .shadow(color: iconColor.opacity(isOn ? 0.35 : 0), radius: 12, x: 0, y: 8)
                    // Optional: subtle brightness indicator
                    Capsule()
                        .fill(iconColor.opacity(isOn ? 0.35 : 0.15))
                        .frame(width: 72, height: 6)
                        .opacity(brightnessOpacity)
                }
            )
            .glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: Constants.cornerRadius * 1.2, style: .continuous)
            )
            .padding(.vertical, DesignSystem.Spaces.two)
            .animation(.easeInOut(duration: 0.2), value: iconColor)
            .animation(.easeInOut(duration: 0.2), value: isOn)
            .animation(.easeInOut(duration: 0.2), value: brightness)
    }

    // MARK: - Brightness Slider

    private var brightnessSlider: some View {
        BrightnessSlider(
            brightness: $brightness,
            color: iconColor
        ) { isEditing in
            if !isEditing {
                // When user finishes dragging, update the light
                Task {
                    await updateBrightness(brightness)
                }
            }
        }
        .frame(width: 60, height: Constants.bulbPreviewHeight)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            modeToggleButton(mode: .color, icon: "paintpalette.fill", label: "Color")
            modeToggleButton(mode: .temperature, icon: "thermometer.medium", label: "Temperature")
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
    }

    private func modeToggleButton(mode: ColorMode, icon: String, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentColorMode = mode
            }
            triggerHaptic += 1
        } label: {
            HStack(spacing: DesignSystem.Spaces.one) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        currentColorMode == mode ? Color.accentColor
                            .opacity(0.15) : Color(uiColor: .secondarySystemBackground)
                    )
            )
            .foregroundStyle(currentColorMode == mode ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            Spacer()
            controlIconButton(system: "power") {
                triggerHaptic += 1
                Task { await toggleLight() }
            }

            // Only show color picker in color mode and if light supports color
            if currentColorMode == .color, supportsColor() {
                colorPickerSwatch
            }

            Spacer()
        }
        .frame(height: Constants.controlBarHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .sensoryFeedback(.impact, trigger: triggerHaptic)
    }

    // MARK: - Temperature Slider

    private var temperatureSlider: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 20))

                Slider(
                    value: $colorTemperature,
                    in: minMireds ... maxMireds,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            Task {
                                await updateColorTemperature(colorTemperature)
                            }
                        }
                    }
                )
                .tint(temperatureGradient)

                Image(systemName: "moon.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 20))
            }
            .padding(.horizontal, DesignSystem.Spaces.four)

            Text("\(kelvinFromMireds(colorTemperature))K")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignSystem.Spaces.two)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var temperatureGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 1.0, green: 0.7, blue: 0.4), // Warm
                Color(red: 1.0, green: 0.9, blue: 0.8), // Neutral
                Color(red: 0.7, green: 0.8, blue: 1.0), // Cool
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func kelvinFromMireds(_ mireds: Double) -> Int {
        Int(1_000_000 / mireds)
    }

    private func controlIconButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemBackground))
                Image(systemName: system)
                    .font(.system(size: Constants.controlIconSize, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color Presets

    private var colorPresetsGrid: some View {
        // Default colors shown when no recent colors exist
        let defaultPresets: [Color] = [
            Color(red: 1.00, green: 0.58, blue: 0.45),
            Color(red: 1.00, green: 0.75, blue: 0.47),
            Color(red: 1.00, green: 0.63, blue: 0.73),
            Color(red: 1.00, green: 0.84, blue: 0.73),
            Color(red: 0.99, green: 0.59, blue: 0.51),
            Color(red: 1.00, green: 0.83, blue: 0.66),
            Color(red: 1.00, green: 0.78, blue: 0.79),
        ]

        // Combine recent colors with defaults to fill up to max spots
        let recentColorsList = recentColors.map { $0.toColor() }
        var displayColors: [(color: Color, isRecent: Bool)] = recentColorsList.map { ($0, true) }

        // Fill remaining spots with default presets
        if displayColors.count < Constants.maxColorPresets {
            let remainingCount = Constants.maxColorPresets - displayColors.count
            let additionalColors = Array(defaultPresets.prefix(remainingCount)).map { ($0, false) }
            displayColors.append(contentsOf: additionalColors)
        }

        return VStack(alignment: .leading, spacing: Constants.swatchSpacing) {
            // Grid of swatches
            ForEach(0 ..< Constants.colorPresetsRows) { row in
                HStack(spacing: Constants.swatchSpacing) {
                    ForEach(0 ..< Constants.colorPresetsColumns) { col in
                        let index = row * Constants.colorPresetsColumns + col
                        if index < displayColors.count {
                            let colorInfo = displayColors[index]
                            swatch(color: colorInfo.color, shouldSaveToRecents: colorInfo.isRecent)
                        } else {
                            Spacer(minLength: Constants.swatchSize)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func swatch(color: Color, shouldSaveToRecents: Bool) -> some View {
        Button {
            triggerHaptic += 1
            Task {
                await updateColor(color, saveToRecents: shouldSaveToRecents)
            }
        } label: {
            Circle()
                .fill(color)
                .overlay(
                    Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .frame(width: Constants.swatchSize, height: Constants.swatchSize)
                .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var colorPickerSwatch: some View {
        ColorPicker("", selection: Binding(
            get: { pickerColor },
            set: { newColor in
                // Only trigger update if we've finished initialization
                guard hasInitialized else {
                    pickerColor = newColor
                    return
                }

                pickerColor = newColor
                triggerHaptic += 1
                Task {
                    await updateColor(newColor, saveToRecents: true)
                }
            }
        ))
        .labelsHidden()
        .frame(width: Constants.swatchSize, height: Constants.swatchSize)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - State Management

    private func updateStateFromEntity() {
        guard let haEntity else {
            isOn = false
            brightness = 0
            selectedColor = .white
            iconColor = .secondary
            return
        }

        // Set flag to prevent color picker onChange from firing
        isUpdatingFromServer = true
        defer { isUpdatingFromServer = false }

        isOn = haEntity.state == "on"

        if let brightnessValue = haEntity.attributes["brightness"] as? Int {
            brightness = Double(brightnessValue) / 255.0 * 100.0
        } else {
            brightness = isOn ? 100 : 0
        }

        let colorMode = haEntity.attributes["color_mode"] as? String
        let rgbColor = haEntity.attributes["rgb_color"] as? [Int]
        let hsColor = haEntity.attributes["hs_color"] as? [Double]
        let colorTemp = haEntity.attributes["color_temp"] as? Int

        // Update color temperature if available
        if let colorTemp {
            colorTemperature = Double(colorTemp)
        }

        // Update temperature range if provided by the entity
        if let minMiredsValue = haEntity.attributes["min_mireds"] as? Int {
            minMireds = Double(minMiredsValue)
        }
        if let maxMiredsValue = haEntity.attributes["max_mireds"] as? Int {
            maxMireds = Double(maxMiredsValue)
        }

        // Determine current mode based on color_mode from server
        // But also consider what the light actually supports
        if let colorMode {
            if colorMode == "color_temp", supportsColorTemp() {
                currentColorMode = .temperature
            } else if ["rgb", "rgbw", "rgbww", "hs", "xy"].contains(colorMode), supportsColor() {
                currentColorMode = .color
            }
        } else {
            // If no color_mode specified, default based on what's supported
            if supportsColor() {
                currentColorMode = .color
            } else if supportsColorTemp() {
                currentColorMode = .temperature
            }
        }

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
            if !colorsAreEqual(iconColor, selectedColor) {
                selectedColor = iconColor
            }
        }
    }

    private func supportsColor() -> Bool {
        guard let haEntity else { return false }
        if let supportedColorModes = haEntity.attributes["supported_color_modes"] as? [String] {
            return supportedColorModes.contains(where: { mode in
                ["rgb", "rgbw", "rgbww", "hs", "xy"].contains(mode)
            })
        }
        return false
    }

    private func supportsColorTemp() -> Bool {
        guard let haEntity else { return false }
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

    private func toggleLight() async {
        let intent = ToggleLightIntent()
        intent.light = createLightEntity()
        intent.turnOn = !isOn

        do {
            let _ = try await intent.perform()
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

    private func updateBrightness(_ value: Double) async {
        // If light is off and brightness is increased, turn it on
        if !isOn, value > 0 {
            let turnOnIntent = ToggleLightIntent()
            turnOnIntent.light = createLightEntity()
            turnOnIntent.turnOn = true

            do {
                let _ = try await turnOnIntent.perform()
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
            let _ = try await intent.perform()
            brightness = value
        } catch {
            Current.Log.verbose("Failed to update brightness: \(error)")
        }
    }

    private func updateColor(_ color: Color, saveToRecents: Bool = false) async {
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
            let _ = try await intent.perform()
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

    private func updateColorTemperature(_ mireds: Double) async {
        let intent = SetLightColorTemperatureIntent()
        intent.light = createLightEntity()
        intent.colorTemp = Int(mireds)

        do {
            let _ = try await intent.perform()
            colorTemperature = mireds

            // Update icon color to approximate white tone
            iconColor = colorFromTemperature(mireds)
        } catch {
            Current.Log.verbose("Failed to update color temperature: \(error)")
        }
    }

    private func colorFromTemperature(_ mireds: Double) -> Color {
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

    // MARK: - Intent Helpers

    private func createLightEntity() -> IntentLightEntity {
        IntentLightEntity(
            id: appEntity.entityId,
            entityId: appEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: appEntity.name,
            iconName: appEntity.icon ?? ""
        )
    }

    // MARK: - Helpers

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Color Persistence

    private var recentColorsCacheKey: String {
        "light.recentColors.\(server.identifier.rawValue).\(appEntity.entityId)"
    }

    private func loadRecentColors() async {
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

        // Keep only the most recent colors (leaving room for color picker)
        if updatedColors.count > Constants.maxColorPresets {
            updatedColors = Array(updatedColors.prefix(Constants.maxColorPresets))
        }

        recentColors = updatedColors

        // Save to disk cache
        Current.diskCache.set(updatedColors, for: recentColorsCacheKey).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save recent colors: \(error)")
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

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    @Previewable @State var haEntity: HAEntity? = try? HAEntity(
        entityId: "light.living_room",
        domain: "light",
        state: "on",
        lastChanged: Date(),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Living Room Light",
            "brightness": 200,
            "rgb_color": [255, 200, 100],
            "supported_color_modes": ["rgb", "brightness", "color_temp"],
            "color_mode": "rgb",
            "area_id": "living_room",
            "min_mireds": 153,
            "max_mireds": 500,
            "color_temp": 250,
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    let appEntity = HAAppEntity(
        id: "test-light.living_room",
        entityId: "light.living_room",
        serverId: "test-server",
        domain: "light",
        name: "Living Room Light",
        icon: "mdi:lightbulb",
        rawDeviceClass: nil
    )

    LightControlsView(
        server: ServerFixture.standard,
        appEntity: appEntity,
        haEntity: haEntity
    )
    .padding()
}
