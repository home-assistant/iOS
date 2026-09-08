import Shared
import SwiftUI

/// A ring that fills over the script's duration while the stage text below it walks through what
/// is being moved. Time-driven, so it plays the same on both sides of the handoff.
struct AppMigrationProgressView: View {
    let script: AppMigrationProgressScript

    @State private var progress: Double = 0
    @State private var stageIndex = 0

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            Spacer()
            HAProgressRing(value: progress, size: .large)
            VStack(spacing: DesignSystem.Spaces.one) {
                Text(script.stages[stageIndex])
                    .font(DesignSystem.Font.title2.bold())
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .id(stageIndex)
                Text(L10n.AppMigration.Progress.footnote)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: Sizes.maxWidthForLargerScreens)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spaces.two)
        .background(Color(uiColor: .systemBackground))
        .task {
            withAnimation(.linear(duration: AppMigrationProgressScript.duration)) {
                progress = 1
            }
            let stageDuration = AppMigrationProgressScript.duration / Double(script.stages.count)
            for index in script.stages.indices.dropFirst() {
                try? await Task.sleep(for: .seconds(stageDuration))
                withAnimation(DesignSystem.Animation.default) {
                    stageIndex = index
                }
            }
        }
    }
}

#Preview("Export") {
    AppMigrationProgressView(script: .export)
}

#Preview("Import") {
    AppMigrationProgressView(script: .import)
}
