import Shared
import SwiftUI

/// The native Overview: the same dashboard the web frontend generates for the built-in `home` panel,
/// drawn with the app's own controls.
struct NativeHomeView: View {
    @StateObject private var viewModel: NativeHomeViewModel

    init(server: Server) {
        _viewModel = StateObject(wrappedValue: NativeHomeViewModel(server: server))
    }

    var body: some View {
        Group {
            if let dashboard = viewModel.dashboard {
                HomeDashboardScreen(
                    dashboard: dashboard,
                    context: HomeDashboardContext(
                        registry: viewModel.registry,
                        strings: .app,
                        presenter: viewModel.presenter,
                        perform: viewModel.perform
                    ),
                    onReorderAreas: viewModel.reorderAreas
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.haSecondaryBackground)
            }
        }
        .task {
            await viewModel.start()
        }
    }
}

#Preview {
    NativeHomeView(server: ServerFixture.standard)
}
