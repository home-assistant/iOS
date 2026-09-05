import Shared
import SwiftUI

/// Presents whichever half of the migration `AppMigrationPresenter` has decided on. Applied at the
/// window root via `View.appMigrationCover()`.
struct AppMigrationCoverModifier: ViewModifier {
    @ObservedObject private var presenter = AppMigrationPresenter.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $presenter.presentation) { presentation in
                switch presentation {
                case .export:
                    AppMigrationFlowView(onDismiss: { presenter.dismiss() })
                case let .importing(chunk):
                    AppMigrationImportFlowView(chunk: chunk, onDismiss: { presenter.dismiss() })
                }
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                presenter.promptIfNeeded()
            }
    }
}
