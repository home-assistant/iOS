import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct LockControlsView: View {
    let haEntity: HAEntity

    @State private var viewModel: LockControlsViewModel

    init(server: Server, haEntity: HAEntity) {
        self.haEntity = haEntity
        self._viewModel = State(initialValue: LockControlsViewModel(
            server: server,
            haEntity: haEntity
        ))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.four) {
            // Header with state
            header
            Spacer()
            // Vertical lock control
            verticalLockControl
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
                .animation(.easeInOut, value: viewModel.isLocked)
        }
    }

    // MARK: - Vertical Lock Control

    private var verticalLockControl: some View {
        VerticalToggleControl(
            isOn: Binding(
                get: { viewModel.isLocked },
                set: { newValue in
                    // Don't update directly, let the ViewModel handle it
                    if newValue != viewModel.isLocked {
                        Task {
                            await viewModel.toggleLock()
                        }
                    }
                }
            ),
            icon: viewModel.lockIcon,
            accentColor: .Domain.lock,
            isDisabled: viewModel.isUpdating
        )
    }

    // MARK: - Toggle Button

    private var toggleButton: some View {
        Button {
            Task {
                await viewModel.toggleLock()
            }
        } label: {
            Image(systemSymbol: viewModel.isLocked ? .lockFill : .lockOpen)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 60, height: 60)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Circle())
        .disabled(viewModel.isUpdating)
        .animation(.easeInOut, value: viewModel.isLocked)
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Lock Locked") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "lock.front_door",
        domain: "lock",
        state: "locked",
        lastChanged: Date().addingTimeInterval(-3600),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Front Door",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    LockControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Lock Unlocked") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "lock.front_door",
        domain: "lock",
        state: "unlocked",
        lastChanged: Date().addingTimeInterval(-7200),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Front Door",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    LockControlsView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}
