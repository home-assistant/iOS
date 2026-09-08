import Shared
import SwiftUI

/// The moment the setup has landed: a checkmark draws itself on in the middle of an empty screen,
/// then glides up into the illustration slot as the completion details fade in around it.
struct AppMigrationSuccessView: View {
    static let checkmarkID = "app-migration-checkmark"
    static let centeredSize: CGFloat = 150
    static let revealDelay: TimeInterval = 1.6
    static let revealAnimation = Animation.spring(response: 0.6, dampingFraction: 0.85)

    let summary: AppMigrationSummary
    let continueAction: () -> Void

    @Namespace private var namespace
    @State private var showsDetails = false
    @State private var isSettled = false

    var body: some View {
        ZStack {
            if showsDetails {
                AppMigrationCompleteView(
                    summary: summary,
                    checkmarkNamespace: namespace,
                    checkmarkSettled: isSettled,
                    continueAction: continueAction
                )
                .transition(.opacity)
            } else {
                Color.clear
                    .frame(width: Self.centeredSize, height: Self.centeredSize)
                    .matchedGeometryEffect(id: Self.checkmarkID, in: namespace)
            }
            if !isSettled {
                CheckmarkDrawOnView(size: Self.centeredSize, tint: .haSuccessColor)
                    .matchedGeometryEffect(id: Self.checkmarkID, in: namespace, isSource: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .task {
            try? await Task.sleep(for: .seconds(Self.revealDelay))
            withAnimation(Self.revealAnimation) {
                showsDetails = true
            }
            try? await Task.sleep(for: .seconds(0.6))
            isSettled = true
        }
    }
}

#Preview {
    AppMigrationSuccessView(summary: .preview, continueAction: {})
}
