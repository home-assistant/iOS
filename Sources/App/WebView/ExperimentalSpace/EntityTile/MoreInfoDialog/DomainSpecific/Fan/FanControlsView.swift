import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct FanControlsView: View {
    enum Constants {
        static let speedSliderHeight: CGFloat = 360
        static let controlIconSize: CGFloat = 20
        static let controlButtonSize: CGFloat = 60
        static let cornerRadius: CGFloat = 28
    }

    let haEntity: HAEntity

    @State private var viewModel: FanControlsViewModel
    @State private var triggerHaptic = 0

    init(server: Server, haEntity: HAEntity) {
        self.haEntity = haEntity
        self._viewModel = State(initialValue: FanControlsViewModel(
            server: server,
            haEntity: haEntity
        ))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.four) {
            // Header with state
            header

            if viewModel.supportsSpeedPercentage {
                // Speed control slider
                speedSlider
            } else {
                Spacer()
                // Simple toggle for fans without speed control
                verticalToggleControl
            }

            // Control buttons
            controlBar

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
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(viewModel.stateDescription())
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
                .animation(.easeInOut, value: viewModel.isOn)

            if viewModel.supportsSpeedPercentage {
                Text("\(Int(viewModel.speed))%")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: viewModel.speed)
            }
        }
    }

    // MARK: - Speed Slider

    private var speedSlider: some View {
        VerticalSlider(
            value: $viewModel.speed,
            in: 0 ... 100,
            step: 1,
            tint: .Domain.fan,
        ) { isEditing in
            if !isEditing {
                // When user finishes dragging, update the fan speed
                triggerHaptic += 1
                Task {
                    await viewModel.updateSpeed(viewModel.speed)
                }
            }
        }
        .frame(height: Constants.speedSliderHeight)
        .sensoryFeedback(.impact, trigger: triggerHaptic)
    }

    // MARK: - Vertical Toggle Control

    private var verticalToggleControl: some View {
        VerticalToggleControl(
            isOn: Binding(
                get: { viewModel.isOn },
                set: { _ in }
            ),
            icon: .fanFill,
            onToggle: {
                Task {
                    await viewModel.toggleFan()
                }
            }
        )
        .frame(height: Constants.speedSliderHeight)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            Spacer()

            // Power button
            controlIconButton(
                symbol: .power,
                isSelected: false
            ) {
                triggerHaptic += 1
                Task { await viewModel.toggleFan() }
            }

            // Oscillation button (if supported)
            if viewModel.supportsOscillation {
                controlIconButton(
                    symbol: SFSymbol(rawValue: "arrow-oscillating"),
                    isSelected: viewModel.oscillating
                ) {
                    triggerHaptic += 1
                    Task { await viewModel.toggleOscillation() }
                }
            }

            // Direction button (if supported)
            if viewModel.supportsDirection {
                controlIconButton(
                    symbol: viewModel.direction == "forward" ? .arrowClockwise : .arrowCounterclockwise,
                    isSelected: viewModel.direction == "reverse"
                ) {
                    triggerHaptic += 1
                    Task { await viewModel.toggleDirection() }
                }
            }

            Spacer()
        }
        .frame(height: Constants.controlButtonSize)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .sensoryFeedback(.impact, trigger: triggerHaptic)
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
            .frame(width: Constants.controlButtonSize, height: Constants.controlButtonSize)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUpdating)
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Fan with Speed Control") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "fan.living_room_fan",
        domain: "fan",
        state: "on",
        lastChanged: Date().addingTimeInterval(-3600),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Living Room Fan",
            "percentage": 75,
            "oscillating": true,
            "direction": "forward",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    FanControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Fan Off") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "fan.bedroom_fan",
        domain: "fan",
        state: "off",
        lastChanged: Date().addingTimeInterval(-7200),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Bedroom Fan",
            "percentage": 0,
            "oscillating": false,
            "direction": "forward",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    FanControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Simple Fan (No Speed Control)") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "fan.simple_fan",
        domain: "fan",
        state: "on",
        lastChanged: Date().addingTimeInterval(-1800),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Simple Fan",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    FanControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}
