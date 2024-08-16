import Shared
import SwiftUI

struct WatchHomeCoordinatorView: View {
    @StateObject private var viewModel = WatchHomeCoordinatorViewModel()

    init() {
        MaterialDesignIcons.register()
    }

    var body: some View {
        navigation
            .onAppear {
                viewModel.initialRoutine()
            }
    }

    @ViewBuilder
    private var navigation: some View {
        if #available(watchOS 10, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.homeType {
        case .undefined:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(2)
        case .empty:
            List {
                Text(L10n.Watch.Labels.noConfig)
                reloadButton
            }
        case let .config(watchConfig, magicItemsInfo):
            WatchHomeView(watchConfig: watchConfig, magicItemsInfo: magicItemsInfo) {
                viewModel.requestConfig()
            }
        }
    }

    private var reloadButton: some View {
        Button {
            viewModel.requestConfig()
        } label: {
            Label(L10n.reloadLabel, systemImage: "arrow.circlepath")
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.footnote)
        }
        .listRowBackground(Color.clear)
    }
}

#Preview {
    WatchHomeCoordinatorView()
}
