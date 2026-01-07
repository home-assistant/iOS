import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct InputBooleanControlsView: View {
    let haEntity: HAEntity

    @State private var viewModel: InputBooleanControlsViewModel

    init(server: Server, haEntity: HAEntity) {
        self.haEntity = haEntity
        self._viewModel = State(initialValue: InputBooleanControlsViewModel(
            server: server,
            haEntity: haEntity
        ))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.four) {
            // Header with state
            header
            Spacer()
            // Vertical toggle control
            verticalToggleControl
            // Toggle button
            toggleButton
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
        }
    }

    // MARK: - Vertical Toggle Control

    private var verticalToggleControl: some View {
        VerticalToggleControl(
            isOn: Binding(
                get: { viewModel.isOn },
                set: { newValue in
                    // Don't update directly, let the ViewModel handle it
                    if newValue != viewModel.isOn {
                        Task {
                            await viewModel.toggleInputBoolean()
                        }
                    }
                }
            ),
            icon: viewModel.inputBooleanIcon,
            accentColor: .Domain.inputBoolean,
            isDisabled: viewModel.isUpdating
        )
    }

    // MARK: - Toggle Button

    private var toggleButton: some View {
        Button {
            Task {
                await viewModel.toggleInputBoolean()
            }
        } label: {
            Image(systemSymbol: .power)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 60, height: 60)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Circle())
        .disabled(viewModel.isUpdating)
        .animation(.easeInOut, value: viewModel.isOn)
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Input Boolean On") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "input_boolean.test_toggle",
        domain: "input_boolean",
        state: "on",
        lastChanged: Date().addingTimeInterval(-3600),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Test Toggle",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    InputBooleanControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Input Boolean Off") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "input_boolean.test_toggle",
        domain: "input_boolean",
        state: "off",
        lastChanged: Date().addingTimeInterval(-7200),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Test Toggle",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    InputBooleanControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}
