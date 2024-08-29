import Shared
import SwiftUI

struct WatchHomeCoordinatorView: View {
    @StateObject private var viewModel = WatchHomeCoordinatorViewModel()
    @State private var showAssist = false

    init() {
        MaterialDesignIcons.register()
    }

    var body: some View {
        navigation
            .onReceive(NotificationCenter.default.publisher(for: AssistDefaultComplication.launchNotification)) { _ in
                showAssist = true
            }
            .fullScreenCover(isPresented: $viewModel.isLoading, content: {
                loadingState
            })
            .fullScreenCover(isPresented: $showAssist, content: {
                if let config = viewModel.config {
                    WatchAssistView.build(
                        serverId: config.assist.serverId,
                        pipelineId: config.assist.pipelineId
                    )
                } else {
                    Text(L10n.Watch.Assist.LackConfig.Error.title)
                }
            })
            .onAppear {
                viewModel.initialRoutine()
            }
    }

    @ViewBuilder
    private var navigation: some View {
        if #available(watchOS 10, *) {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            navReloadButton
                        }
                        if let config = viewModel.config,
                           config.assist.showAssist,
                           !config.assist.serverId.isEmpty,
                           !config.assist.pipelineId.isEmpty {
                            ToolbarItem(placement: .topBarTrailing) {
                                assistButton
                            }
                        }
                    }
            }
        } else {
            NavigationView {
                content
                    .toolbar {
                        if #available(watchOS 9.0, *), let config = viewModel.config, config.assist.showAssist {
                            assistButton
                        }
                    }
            }
        }
    }

    private var assistButton: some View {
        Button(action: {
            showAssist = true
        }, label: {
            Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                ofSize: .init(width: 24, height: 24),
                color: Asset.Colors.haPrimary.color
            ))
        })
    }

    private var loadingState: some View {
        VStack {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(2)
            Button(L10n.Watch.Home.CancelAndUseCache.title) {
                viewModel.loadCache()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch viewModel.homeType {
            case .undefined:
                reloadButton
            case .empty:
                List {
                    Text(L10n.Watch.Labels.noConfig)
                        .font(.footnote)
                    reloadButton
                }
            case let .config(watchConfig, magicItemsInfo):
                WatchHomeView(watchConfig: watchConfig, magicItemsInfo: magicItemsInfo) {
                    viewModel.requestConfig()
                }
            case let .error(errorMessage):
                List {
                    Text(errorMessage)
                    reloadButton
                }
            }
        }
        .navigationTitle("")
    }

    private var navReloadButton: some View {
        Button {
            viewModel.requestConfig()
        } label: {
            Image(systemName: "arrow.circlepath")
        }
    }

    @ViewBuilder
    private var reloadButton: some View {
        // When watchOS 10 is available, reload is on toolbar
        if #unavailable(watchOS 10.0) {
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
}

#Preview {
    WatchHomeCoordinatorView()
}
