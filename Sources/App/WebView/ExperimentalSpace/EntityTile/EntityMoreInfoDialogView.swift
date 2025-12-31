import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct EntityMoreInfoDialogView: View {
    enum Constants {
        static let dialogMaxWidth: CGFloat = 400
        static let dialogMaxHeight: CGFloat = 600
        static let cornerRadius: CGFloat = 24
        static let headerSpacing: CGFloat = 4
        static let sectionSpacing: CGFloat = 20
        static let controlHeight: CGFloat = 56
        static let colorPickerSize: CGFloat = 280
        static let colorPickerStrokeWidth: CGFloat = 40
        static let brightnessIconSize: CGFloat = 20
    }
    
    let server: Server
    let appEntity: HAAppEntity
    let haEntity: HAEntity?
    @Environment(\.dismiss) private var dismiss
    
    @State private var brightness: Double = 0
    @State private var selectedColor: Color = .white
    @State private var isOn: Bool = false
    @State private var triggerHaptic = 0
    
    init(server: Server, appEntity: HAAppEntity, haEntity: HAEntity?) {
        self.server = server
        self.appEntity = appEntity
        self.haEntity = haEntity
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spaces.three) {
                    switch Domain(entityId: appEntity.entityId) {
                    case .light:
                        lightControlsView
                    default:
                        Text("More controls coming soon")
                            .font(DesignSystem.Font.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DesignSystem.Spaces.four)
                    }
                }
                .padding(.horizontal, DesignSystem.Spaces.three)
            }
            .padding(.top, DesignSystem.Spaces.three)
            .padding(.bottom, DesignSystem.Spaces.two)
            .frame(maxWidth: Constants.dialogMaxWidth, maxHeight: Constants.dialogMaxHeight)
            .glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
            )
            .navigationTitle(appEntity.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        triggerHaptic += 1
                        dismiss()
                    }
                }
            }
            .onAppear {
                updateStateFromEntity()
            }
            .onChange(of: haEntity) { _, _ in
                updateStateFromEntity()
            }
        }
    }

    // MARK: - Light Controls
    
    @ViewBuilder
    private var lightControlsView: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            // On/Off Button
            toggleButton
            
            // Brightness Control
            if isOn {
                brightnessControl
                
                // Color Picker
                if supportsColor() {
                    colorPickerView
                }
            }
        }
    }
    
    private var toggleButton: some View {
        Button {
            triggerHaptic += 1
            Task {
                await toggleLight()
            }
        } label: {
            HStack {
                Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? selectedColor : .secondary)
                
                Text(isOn ? "Turn Off" : "Turn On")
                    .font(DesignSystem.Font.headline)
                    .foregroundColor(Color(uiColor: .label))
                
                Spacer()
                
                Image(systemName: "power")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
            .frame(height: Constants.controlHeight)
            .frame(maxWidth: .infinity)
            .glassEffect(
                .clear.interactive(),
                in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: triggerHaptic)
    }
    
    private var brightnessControl: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            HStack {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: Constants.brightnessIconSize))
                    .foregroundStyle(.secondary)
                
                Text("Brightness")
                    .font(DesignSystem.Font.subheadline)
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                
                Spacer()
                
                Text("\(Int(brightness))%")
                    .font(DesignSystem.Font.subheadline)
                    .foregroundColor(Color(uiColor: .label))
                    .fontWeight(.medium)
            }
            
            Slider(value: $brightness, in: 0...100, step: 1)
                .tint(selectedColor)
                .onChange(of: brightness) { _, newValue in
                    Task {
                        await updateBrightness(newValue)
                    }
                }
        }
        .padding(DesignSystem.Spaces.two)
        .glassEffect(
            .clear,
            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two, style: .continuous)
        )
    }
    
    private var colorPickerView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Text("Color")
                .font(DesignSystem.Font.subheadline)
                .foregroundColor(Color(uiColor: .secondaryLabel))
            
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .onChange(of: selectedColor) { _, newColor in
                    Task {
                        await updateColor(newColor)
                    }
                }
        }
        .padding(DesignSystem.Spaces.two)
        .glassEffect(
            .clear,
            in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two, style: .continuous)
        )
    }
    
    // MARK: - Helper Methods
    
    private func updateStateFromEntity() {
        guard let haEntity else {
            isOn = false
            brightness = 0
            selectedColor = .white
            return
        }
        
        // Update on/off state
        isOn = haEntity.state == "on"
        
        // Update brightness (Home Assistant uses 0-255, we use 0-100)
        if let brightnessValue = haEntity.attributes["brightness"] as? Int {
            brightness = Double(brightnessValue) / 255.0 * 100.0
        } else {
            brightness = isOn ? 100 : 0
        }
        
        // Update color
        let colorMode = haEntity.attributes["color_mode"] as? String
        let rgbColor = haEntity.attributes["rgb_color"] as? [Int]
        let hsColor = haEntity.attributes["hs_color"] as? [Double]
        
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
            selectedColor = EntityIconColorProvider.iconColor(
                state: haEntity.state,
                colorMode: colorMode,
                rgbColor: rgbColor,
                hsColor: hsColor
            )
        }
    }
    
    private func supportsColor() -> Bool {
        guard let haEntity else { return false }
        
        // Check if the light supports color
        if let supportedColorModes = haEntity.attributes["supported_color_modes"] as? [String] {
            return supportedColorModes.contains(where: { mode in
                ["rgb", "rgbw", "rgbww", "hs", "xy"].contains(mode)
            })
        }
        
        return false
    }
    
    // MARK: - Service Calls
    
    private func toggleLight() async {
        let newState = !isOn
        let service = newState ? "turn_on" : "turn_off"
        
        await callLightService(service: service, data: [:])
        
        // Optimistically update UI
        isOn = newState
        if !newState {
            brightness = 0
        }
    }
    
    private func updateBrightness(_ value: Double) async {
        guard isOn else { return }
        
        // Convert 0-100 to 0-255 for Home Assistant
        let hasBrightness = Int(value / 100.0 * 255.0)
        
        await callLightService(service: "turn_on", data: [
            "brightness": hasBrightness
        ])
    }
    
    private func updateColor(_ color: Color) async {
        guard isOn else { return }
        
        // Convert SwiftUI Color to RGB values
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgbColor = [
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        ]
        
        await callLightService(service: "turn_on", data: [
            "rgb_color": rgbColor
        ])
    }
    
    private func callLightService(service: String, data: [String: Any]) async {
        // This is a placeholder for the actual service call implementation
        // You'll need to integrate with your existing HomeAssistantAPI or HAConnection
        // based on how the rest of your app handles service calls
        
        // Example implementation pattern (adjust based on your actual API):
        /*
        guard let api = Current.api(for: server) else { return }
        
        do {
            _ = try await api.connection.send(
                .callService(
                    domain: .init(rawValue: "light"),
                    service: .init(rawValue: service),
                    data: ["entity_id": appEntity.entityId].merging(data) { _, new in new }
                )
            )
        } catch {
            print("Failed to call service: \(error)")
        }
        */
        
        print("Calling service: light.\(service) for \(appEntity.entityId) with data: \(data)")
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
            "area_id": "living_room"
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
    
    EntityMoreInfoDialogView(
        server: ServerFixture.standard,
        appEntity: appEntity,
        haEntity: haEntity
    )
}
