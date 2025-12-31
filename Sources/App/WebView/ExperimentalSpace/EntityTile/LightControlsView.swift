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
    }

    let server: Server
    let appEntity: HAAppEntity
    let haEntity: HAEntity?

    @State private var brightness: Double = 0
    @State private var selectedColor: Color = .white
    @State private var isOn: Bool = false
    @State private var triggerHaptic = 0
    @State private var iconColor: Color = .secondary

    // UI state
    @State private var showColorPresets: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.four) {
                header
                bulbPreview
                controlBar
                if showColorPresets {
                    colorPresetsGrid
                }
                effectButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { updateStateFromEntity() }
        .onChange(of: haEntity) { _, _ in updateStateFromEntity() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text(stateDescription)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
                .animation(.easeInOut, value: isOn)
            if let updated = haEntity?.lastUpdated {
                Text(relativeDateString(from: updated))
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spaces.two)
            .animation(.easeInOut(duration: 0.2), value: iconColor)
            .animation(.easeInOut(duration: 0.2), value: isOn)
            .animation(.easeInOut(duration: 0.2), value: brightness)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            controlIconButton(system: "power") {
                triggerHaptic += 1
                Task { await toggleLight() }
            }
            controlIconButton(system: "gearshape") {
                // Placeholder for settings/details
            }
            controlIconButton(system: "circle.lefthalf.filled") {
                // Toggle color presets visibility
                withAnimation(.easeInOut) { showColorPresets.toggle() }
            }
            controlIconButton(system: "sun.max") {
                // Quick warm preset
                Task { await updateColor(Color(hue: 40 / 360, saturation: 0.25, brightness: 1.0)) }
            }
        }
        .frame(height: Constants.controlBarHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .glassEffect(
            .clear,
            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two, style: .continuous)
        )
        .sensoryFeedback(.impact, trigger: triggerHaptic)
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
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color Presets

    private var colorPresetsGrid: some View {
        let presets: [Color] = [
            Color(red: 1.00, green: 0.58, blue: 0.45),
            Color(red: 1.00, green: 0.75, blue: 0.47),
            Color(red: 1.00, green: 0.63, blue: 0.73),
            Color(red: 1.00, green: 0.84, blue: 0.73),
            Color(red: 0.99, green: 0.59, blue: 0.51),
            Color(red: 1.00, green: 0.83, blue: 0.66),
            Color(red: 1.00, green: 0.78, blue: 0.79),
            Color(red: 1.00, green: 0.93, blue: 0.87),
        ]

        return VStack(alignment: .leading, spacing: Constants.swatchSpacing) {
            // Two rows of swatches (4 per row)
            ForEach(0 ..< 2) { row in
                HStack(spacing: Constants.swatchSpacing) {
                    ForEach(0 ..< 4) { col in
                        let index = row * 4 + col
                        if index < presets.count {
                            swatch(color: presets[index])
                        } else {
                            Spacer(minLength: Constants.swatchSize)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func swatch(color: Color) -> some View {
        Button {
            Task { await updateColor(color) }
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

    // MARK: - Effect Button

    private var effectButton: some View {
        Button {
            // Placeholder for effects sheet
        } label: {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                Text("Effect")
                    .font(DesignSystem.Font.headline)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two, style: .continuous)
            )
        }
        .buttonStyle(.plain)
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

        isOn = haEntity.state == "on"

        if let brightnessValue = haEntity.attributes["brightness"] as? Int {
            brightness = Double(brightnessValue) / 255.0 * 100.0
        } else {
            brightness = isOn ? 100 : 0
        }

        let colorMode = haEntity.attributes["color_mode"] as? String
        let rgbColor = haEntity.attributes["rgb_color"] as? [Int]
        let hsColor = haEntity.attributes["hs_color"] as? [Double]

        // Update icon color using the same logic as EntityTileView
        iconColor = EntityIconColorProvider.iconColor(
            state: haEntity.state,
            colorMode: colorMode,
            rgbColor: rgbColor,
            hsColor: hsColor
        )

        // Update selected color for the UI controls
        if let rgbColor, rgbColor.count == 3 {
            selectedColor = Color(
                red: Double(rgbColor[0]) / 255.0,
                green: Double(rgbColor[1]) / 255.0,
                blue: Double(rgbColor[2]) / 255.0
            )
        } else if let hsColor, hsColor.count == 2 {
            let hue = hsColor[0] / 360.0
            let saturation = hsColor[1] / 100.0
            selectedColor = Color(hue: hue, saturation: saturation, brightness: 1.0)
        } else {
            selectedColor = iconColor
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

    // MARK: - Service Calls

    private func toggleLight() async {
        await Current.connectivity.syncNetworkInformation()
        guard let connection = Current.api(for: server)?.connection else {
            return
        }

        let newState = !isOn
        let service = newState ? Service.turnOn.rawValue : Service.turnOff.rawValue

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: service),
                data: [
                    "entity_id": appEntity.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        // Update local state
        isOn = newState
        if !newState { brightness = 0 }
    }

    private func updateBrightness(_ value: Double) async {
        guard isOn else { return }
        await Current.connectivity.syncNetworkInformation()
        guard let connection = Current.api(for: server)?.connection else {
            return
        }

        let hasBrightness = Int(value / 100.0 * 255.0)

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: Service.turnOn.rawValue),
                data: [
                    "entity_id": appEntity.entityId,
                    "brightness": hasBrightness,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }
    }

    private func updateColor(_ color: Color) async {
        guard isOn else { return }
        await Current.connectivity.syncNetworkInformation()
        guard let connection = Current.api(for: server)?.connection else {
            return
        }

        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgbColor = [Int(red * 255), Int(green * 255), Int(blue * 255)]

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: Service.turnOn.rawValue),
                data: [
                    "entity_id": appEntity.entityId,
                    "rgb_color": rgbColor,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        // Update local state
        selectedColor = color
        iconColor = color
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
            "supported_color_modes": ["rgb", "brightness"],
            "color_mode": "rgb",
            "area_id": "living_room",
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
