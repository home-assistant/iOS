import Shared
import SwiftUI

/// The bar shown under the step list while a payload crosses in more than one link.
///
/// Its job is to explain the app switching the user is about to watch: without it, bouncing between
/// two apps looks like a bug rather than a transfer making progress.
struct AppMigrationTransferProgressView: View {
    let progress: AppMigrationTransferProgress
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
                .tint(Color.haPrimary)

            Text(caption)
                .font(DesignSystem.Font.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
    }
}

#Preview {
    AppMigrationTransferProgressView(
        progress: .init(completed: 2, total: 5),
        caption: "Part 3 of 5 — this app and the new one will swap a few times."
    )
}
