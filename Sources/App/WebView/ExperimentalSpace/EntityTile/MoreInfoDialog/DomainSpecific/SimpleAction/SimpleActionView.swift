import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct SimpleActionView: View {
    let haEntity: HAEntity

    @State private var viewModel: SimpleActionViewModel
    @State private var triggerHaptic = 0

    init(server: Server, haEntity: HAEntity) {
        self.haEntity = haEntity
        self._viewModel = State(initialValue: SimpleActionViewModel(
            server: server,
            haEntity: haEntity
        ))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.four) {
            // Header with last executed info
            header
            Spacer()
            // Action button
            actionButton
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
        .sensoryFeedback(.success, trigger: triggerHaptic)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(viewModel.stateDescription())
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)

            if let lastExecuted = viewModel.lastExecuted {
                Text(relativeDateString(from: lastExecuted))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button {
            Task {
                await viewModel.executeAction()
                triggerHaptic += 1
            }
        } label: {
            VStack(spacing: DesignSystem.Spaces.two) {
                Image(systemSymbol: viewModel.actionIcon)
                    .font(.system(size: 48, weight: .semibold))
                    .frame(width: 120, height: 120)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Circle())

                Text(viewModel.actionLabel)
                    .font(.system(size: 20, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isExecuting)
        .opacity(viewModel.isExecuting ? 0.5 : 1.0)
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
#Preview("Button Entity") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "button.doorbell",
        domain: "button",
        state: "2024-01-01T12:00:00.000000+00:00",
        lastChanged: Date().addingTimeInterval(-3600),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Doorbell",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    SimpleActionView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Scene Entity") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "scene.movie_time",
        domain: "scene",
        state: "2024-01-01T18:00:00.000000+00:00",
        lastChanged: Date().addingTimeInterval(-7200),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Movie Time",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    SimpleActionView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}

@available(iOS 26.0, *)
#Preview("Script Entity") {
    // swiftlint:disable:next force_try
    let haEntity = try! HAEntity(
        entityId: "script.good_night",
        domain: "script",
        state: "2024-01-01T22:00:00.000000+00:00",
        lastChanged: Date().addingTimeInterval(-3600),
        lastUpdated: Date(),
        attributes: [
            "friendly_name": "Good Night",
        ],
        context: .init(id: "", userId: nil, parentId: nil)
    )

    SimpleActionView(
        server: ServerFixture.standard,
        haEntity: haEntity
    )
    .padding()
}
