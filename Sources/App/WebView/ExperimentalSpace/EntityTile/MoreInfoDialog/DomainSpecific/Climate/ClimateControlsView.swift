import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct ClimateControlsView: View {
    enum Constants {
        static let temperatureSliderHeight: CGFloat = 360
        static let controlButtonSize: CGFloat = 60
        static let modeButtonWidth: CGFloat = 80
        static let modeButtonHeight: CGFloat = 50
    }

    let haEntity: HAEntity

    @State private var viewModel: ClimateControlsViewModel
    @State private var triggerHaptic = 0

    init(server: Server, haEntity: HAEntity) {
        self.haEntity = haEntity
        self._viewModel = State(initialValue: ClimateControlsViewModel(
            server: server,
            haEntity: haEntity
        ))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.four) {
            // Header with temperatures
            header

            // Temperature slider
            temperatureSlider

            // HVAC mode buttons
            hvacModeButtons

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DesignSystem.Spaces.two)
        .onAppear {
            viewModel.initialize()
        }
        .onChange(of: haEntity) { _, newValue in
            viewModel.updateEntity(newValue)
        }
        .sensoryFeedback(.impact, trigger: triggerHaptic)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            // Current mode
            Text(viewModel.hvacModeDisplayName(viewModel.hvacMode))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
                .animation(.easeInOut, value: viewModel.hvacMode)

            // Current temperature (if available)
            if let currentTemp = viewModel.currentTemperature {
                Text("Current: \(String(format: "%.1f", currentTemp))\(viewModel.temperatureUnit)")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            // Target temperature
            Text("\(String(format: "%.1f", viewModel.targetTemperature))\(viewModel.temperatureUnit)")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.Domain.climate)
                .animation(.easeInOut, value: viewModel.targetTemperature)
        }
    }

    // MARK: - Temperature Slider

    private var temperatureSlider: some View {
        VerticalSlider(
            value: $viewModel.targetTemperature,
            in: viewModel.minTemperature ... viewModel.maxTemperature,
            step: viewModel.temperatureStep,
            tint: .Domain.climate
        ) { isEditing in
            if !isEditing {
                // When user finishes dragging, update the temperature
                triggerHaptic += 1
                Task {
                    await viewModel.setTemperature(viewModel.targetTemperature)
                }
            }
        }
        .frame(height: Constants.temperatureSliderHeight)
        .disabled(viewModel.hvacMode == "off")
    }

    // MARK: - HVAC Mode Buttons

    private var hvacModeButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spaces.one) {
                ForEach(viewModel.availableHvacModes, id: \.self) { mode in
                    hvacModeButton(mode: mode)
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
        }
    }

    private func hvacModeButton(mode: String) -> some View {
        Button {
            triggerHaptic += 1
            Task {
                await viewModel.setHvacMode(mode)
            }
        } label: {
            VStack(spacing: DesignSystem.Spaces.half) {
                Image(systemSymbol: iconForMode(mode))
                    .font(.system(size: 20, weight: .semibold))
                Text(viewModel.hvacModeDisplayName(mode))
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(width: Constants.modeButtonWidth, height: Constants.modeButtonHeight)
            .background(
                viewModel.hvacMode == mode ?
                    Color.Domain.climate.opacity(0.2) :
                    Color(uiColor: .secondarySystemBackground)
            )
            .foregroundStyle(
                viewModel.hvacMode == mode ?
                    Color.Domain.climate :
                    Color.primary
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUpdating)
    }

    private func iconForMode(_ mode: String) -> SFSymbol {
        switch mode {
        case "heat":
            return .flameFill
        case "cool":
            return .snowflake
        case "heat_cool", "auto":
            return .arrowLeftArrowRightCircle
        case "dry":
            return .drop
        case "fan_only":
            return .fanFill
        case "off":
            return .powerCircle
        default:
            return .questionmarkCircle
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Climate Heating") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "climate.living_room",
        domain: "climate",
        state: "heat",
        lastChanged: Date().addingTimeInterval(-3600),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Living Room Climate",
            "current_temperature": 20.5,
            "temperature": 22.0,
            "min_temp": 7,
            "max_temp": 35,
            "target_temp_step": 0.5,
            "hvac_modes": ["off", "heat", "cool", "heat_cool", "auto"],
            "temperature_unit": "°C",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    ClimateControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Climate Off") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "climate.bedroom",
        domain: "climate",
        state: "off",
        lastChanged: Date().addingTimeInterval(-7200),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Bedroom Climate",
            "current_temperature": 21.0,
            "temperature": 20.0,
            "min_temp": 7,
            "max_temp": 35,
            "target_temp_step": 0.5,
            "hvac_modes": ["off", "heat", "cool"],
            "temperature_unit": "°C",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    ClimateControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}
