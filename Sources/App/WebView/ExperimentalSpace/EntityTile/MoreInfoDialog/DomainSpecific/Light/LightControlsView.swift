import HAKit
import SFSafeSymbols
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
        static let maxTemperaturePresets: Int = 7
        // Temperature constants (mireds)
        static let minMireds: Double = 153 // ~6500K (cool white)
        static let maxMireds: Double = 500 // ~2000K (warm white)
    }

    let haEntity: HAEntity

    @State private var viewModel: LightControlsViewModel
    @State private var triggerHaptic = 0
    @State private var showColorPresets: Bool = true

    init(server: Server, haEntity: HAEntity) {
        self.haEntity = haEntity
        self._viewModel = State(initialValue: LightControlsViewModel(
            server: server,
            haEntity: haEntity
        ))
    }

    var body: some View {
        Group {
            if viewModel.supportsBrightness() {
                ScrollView {
                    VStack(spacing: DesignSystem.Spaces.four) {
                        header

                        // Use different control based on brightness support
                        brightnessSlider
                        controlBar

                        // Show appropriate controls based on mode and support
                        if viewModel.supportsColor(), viewModel.currentColorMode == .color, showColorPresets {
                            HStack {
                                Spacer()
                                colorPresetsGrid
                                Spacer()
                            }
                        }

                        if viewModel.supportsColorTemp(), viewModel.currentColorMode == .temperature {
                            temperatureSlider
                        }
                    }
                }
            } else {
                VStack(spacing: DesignSystem.Spaces.four) {
                    header
                    Spacer()
                    // Simple toggle for lights without brightness
                    simpleToggleControl
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical)
        .onAppear {
            viewModel.initialize()
            Task {
                await viewModel.loadRecentColors()
                await viewModel.loadRecentTemperatures()
            }
        }
        .onChange(of: haEntity) { _, newValue in
            viewModel.updateEntity(newValue)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(viewModel.stateDescription())
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
                .animation(.easeInOut, value: viewModel.isOn)

            // Only show brightness percentage if light supports brightness
            if viewModel.supportsBrightness() {
                Text("\(Int(viewModel.brightness))%")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: viewModel.brightness)
            }
        }
    }

    private var stateDescription: String {
        viewModel.stateDescription()
    }

    // MARK: - Bulb Preview

    private var bulbPreview: some View {
        let displayColor = viewModel.isOn ? viewModel.iconColor : Color(uiColor: .systemGray5)
        let brightnessOpacity = viewModel.isOn ? max(0.15, viewModel.brightness / 100.0) : 1.0

        return RoundedRectangle(cornerRadius: Constants.cornerRadius * 1.2, style: .continuous)
            .fill(displayColor.opacity(viewModel.isOn ? 0.25 : 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius * 1.2, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .frame(width: Constants.bulbPreviewWidth, height: Constants.bulbPreviewHeight)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemSymbol: viewModel.isOn ? .lightbulbFill : .lightbulb)
                        .font(.system(size: 36))
                        .foregroundStyle(viewModel.isOn ? viewModel.iconColor : .secondary)
                        .shadow(color: viewModel.iconColor.opacity(viewModel.isOn ? 0.35 : 0), radius: 12, x: 0, y: 8)
                    // Optional: subtle brightness indicator
                    Capsule()
                        .fill(viewModel.iconColor.opacity(viewModel.isOn ? 0.35 : 0.15))
                        .frame(width: 72, height: 6)
                        .opacity(brightnessOpacity)
                }
            )
            .glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: Constants.cornerRadius * 1.2, style: .continuous)
            )
            .padding(.vertical, DesignSystem.Spaces.two)
            .animation(.easeInOut(duration: 0.2), value: viewModel.iconColor)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isOn)
            .animation(.easeInOut(duration: 0.2), value: viewModel.brightness)
    }

    // MARK: - Brightness Slider

    private var brightnessSlider: some View {
        BrightnessSlider(
            brightness: $viewModel.brightness,
            color: viewModel.iconColor,
        ) { isEditing in
            if !isEditing {
                // When user finishes dragging, update the light
                Task {
                    await viewModel.updateBrightness(viewModel.brightness)
                }
            }
        }
        .frame(height: Constants.bulbPreviewHeight)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Simple Toggle Control

    private var simpleToggleControl: some View {
        VerticalToggleControl(
            isOn: Binding(
                get: { viewModel.isOn },
                set: { _ in }
            ),
            icon: .lightbulbFill,
            accentColor: viewModel.iconColor,
            onToggle: {
                Task {
                    await viewModel.toggleLight()
                }
            }
        )
        .frame(height: Constants.bulbPreviewHeight)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            Spacer()
            controlIconButton(symbol: .power) {
                triggerHaptic += 1
                Task { await viewModel.toggleLight() }
            }

            // Show mode toggle buttons if light supports both color and temperature
            if viewModel.supportsColor(), viewModel.supportsColorTemp() {
                controlIconButton(symbol: .paintpaletteFill, isSelected: viewModel.currentColorMode == .color) {
                    triggerHaptic += 1
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.currentColorMode = .color
                    }
                }

                controlIconButton(symbol: .thermometerMedium, isSelected: viewModel.currentColorMode == .temperature) {
                    triggerHaptic += 1
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.currentColorMode = .temperature
                    }
                }
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
            // Temperature presets row
            temperaturePresetsRow

            HStack {
                Image(systemSymbol: .sunMaxFill)
                    .foregroundStyle(.orange)
                    .font(.system(size: 20))

                Slider(
                    value: $viewModel.colorTemperature,
                    in: viewModel.minMireds ... viewModel.maxMireds,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            Task {
                                await viewModel.updateColorTemperature(viewModel.colorTemperature)
                            }
                        }
                    }
                )
                .tint(temperatureGradient)

                Image(systemSymbol: .moonFill)
                    .foregroundStyle(.blue)
                    .font(.system(size: 20))
            }
            .padding(.horizontal, DesignSystem.Spaces.four)

            Text("\(viewModel.kelvinFromMireds(viewModel.colorTemperature))K")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignSystem.Spaces.two)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var temperaturePresetsRow: some View {
        let defaultTemperatures: [Double] = [
            153, // ~6500K (cool/daylight)
            192, // ~5200K
            250, // ~4000K (neutral)
            308, // ~3250K
            370, // ~2700K (warm)
            435, // ~2300K
            500, // ~2000K (very warm)
        ]

        // Combine recent temperatures with defaults
        var displayTemperatures: [Double] = viewModel.recentTemperatures

        // Fill remaining spots with defaults if needed
        if displayTemperatures.count < Constants.maxTemperaturePresets {
            let remainingCount = Constants.maxTemperaturePresets - displayTemperatures.count
            let additionalTemps = Array(defaultTemperatures.prefix(remainingCount))
            displayTemperatures.append(contentsOf: additionalTemps)
        }

        return HStack(spacing: Constants.swatchSpacing) {
            ForEach(0 ..< min(displayTemperatures.count, Constants.maxTemperaturePresets), id: \.self) { index in
                temperatureSwatch(mireds: displayTemperatures[index])
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
    }

    private func temperatureSwatch(mireds: Double) -> some View {
        let color = viewModel.colorFromTemperature(mireds)
        let kelvin = viewModel.kelvinFromMireds(mireds)

        return Button {
            triggerHaptic += 1
            Task {
                await viewModel.updateColorTemperature(mireds)
            }
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .overlay(
                        Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .frame(width: Constants.swatchSize, height: Constants.swatchSize)
                    .shadow(color: color.opacity(0.2), radius: 6, x: 0, y: 4)

                Text("\(kelvin)K")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
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

    private func controlIconButton(
        symbol: SFSymbol,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            action()
        }) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(uiColor: .secondarySystemBackground))
                Image(systemSymbol: symbol)
                    .font(.system(size: Constants.controlIconSize, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color Presets

    private var colorPresetsGrid: some View {
        // Default colors shown when no recent colors exist (7 colors to leave room for picker)
        let defaultPresets: [Color] = [
            Color(red: 1.00, green: 0.58, blue: 0.45),
            Color(red: 1.00, green: 0.75, blue: 0.47),
            Color(red: 1.00, green: 0.63, blue: 0.73),
            Color(red: 1.00, green: 0.84, blue: 0.73),
            Color(red: 0.99, green: 0.59, blue: 0.51),
            Color(red: 1.00, green: 0.83, blue: 0.66),
            Color(red: 1.00, green: 0.78, blue: 0.79),
        ]

        // Combine recent colors with defaults to fill up to 7 spots (8th is color picker)
        let maxPresetColors = Constants.maxColorPresets - 1 // Reserve last spot for picker
        let recentColorsList = viewModel.recentColors.map { $0.toColor() }
        var displayColors: [(color: Color, isRecent: Bool)] = recentColorsList.map { ($0, true) }

        // Fill remaining spots with default presets
        if displayColors.count < maxPresetColors {
            let remainingCount = maxPresetColors - displayColors.count
            let additionalColors = Array(defaultPresets.prefix(remainingCount)).map { ($0, false) }
            displayColors.append(contentsOf: additionalColors)
        }

        return VStack(alignment: .leading, spacing: Constants.swatchSpacing) {
            // Grid of swatches
            ForEach(0 ..< Constants.colorPresetsRows) { row in
                HStack(spacing: Constants.swatchSpacing) {
                    ForEach(0 ..< Constants.colorPresetsColumns) { col in
                        let index = row * Constants.colorPresetsColumns + col
                        let totalSlots = Constants.colorPresetsRows * Constants.colorPresetsColumns

                        // Last slot (index 7) is the color picker
                        if index == totalSlots - 1 {
                            colorPickerSwatch
                        } else if index < displayColors.count {
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
                await viewModel.updateColor(color, saveToRecents: shouldSaveToRecents)
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
            get: { viewModel.pickerColor },
            set: { newColor in
                // Only trigger update if we've finished initialization
                guard viewModel.hasInitialized else {
                    viewModel.pickerColor = newColor
                    return
                }

                viewModel.pickerColor = newColor
                triggerHaptic += 1
                Task {
                    await viewModel.updateColor(newColor, saveToRecents: true)
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

    // MARK: - Helpers

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Light with Brightness Control") {
    @Previewable @State var haEntity: HAEntity! = try? HAEntity(
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
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Simple On/Off Light") {
    @Previewable @State var haEntity: HAEntity! = try? HAEntity(
        entityId: "light.simple_bulb",
        domain: "light",
        state: "on",
        lastChanged: Date(),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Simple Bulb",
            "supported_color_modes": ["onoff"],
            "color_mode": "onoff",
            "area_id": "bedroom",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    let appEntity = HAAppEntity(
        id: "test-light.simple_bulb",
        entityId: "light.simple_bulb",
        serverId: "test-server",
        domain: "light",
        name: "Simple Bulb",
        icon: "mdi:lightbulb-outline",
        rawDeviceClass: nil
    )

    LightControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}
