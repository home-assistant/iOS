import Shared
import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = WatchHomeViewModel()
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
                WatchAssistView.build(
                    serverId: viewModel.watchConfig.assist.serverId,
                    pipelineId: viewModel.watchConfig.assist.pipelineId
                )
            })
            .onAppear {
                viewModel.fetchNetworkInfo(completion: nil)
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
                        if viewModel.showAssist {
                            ToolbarItem(placement: .topBarTrailing) {
                                assistButton
                                    .modify { view in
                                        if #available(watchOS 11, *) {
                                            view.handGestureShortcut(.primaryAction)
                                        } else {
                                            view
                                        }
                                    }
                            }
                        }
                    }
            }
        } else {
            NavigationView {
                content
            }
        }
    }

    private var assistButton: some View {
        Button(action: {
            showAssist = true
        }, label: {
            Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                ofSize: .init(width: 24, height: 24),
                color: UIColor(Color.haPrimary)
            ))
        })
    }

    private var loadingState: some View {
        VStack {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(2)
            Button(L10n.Watch.Home.Loading.Skip.title) {
                viewModel.loadCache()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            if viewModel.showError {
                Text(viewModel.errorMessage)
                    .font(.footnote)
                    .listRowBackground(
                        Color.red.opacity(0.5)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadiusSizes.oneAndHalf))
                    )
            }
            if viewModel.watchConfig.items.isEmpty {
                Text(verbatim: L10n.Watch.Labels.noConfig)
                    .font(.footnote)
            } else {
                mainContent
            }
            if viewModel.watchConfig.items.isEmpty || viewModel.showError {
                reloadButton
            }
            appVersion
        }
        .id(viewModel.refreshListID)
        .navigationTitle("")
    }

    private var appVersion: some View {
        Text(verbatim: AppConstants.version)
            .listRowBackground(Color.clear)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
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

    @ViewBuilder
    private var mainContent: some View {
        if #unavailable(watchOS 10),
           viewModel.watchConfig.assist.showAssist,
           !viewModel.watchConfig.assist.serverId.isEmpty,
           !viewModel.watchConfig.assist.pipelineId.isEmpty {
            assistButton
        }
        ForEach(viewModel.watchConfig.items, id: \.serverUniqueId) { item in
            WatchMagicViewRow(
                item: item,
                itemInfo: info(for: item)
            )
        }
        reloadButton
    }

    private func info(for magicItem: MagicItem) -> MagicItem.Info {
        viewModel.magicItemsInfo.first(where: {
            $0.id == magicItem.serverUniqueId
        }) ?? .init(
            id: magicItem.id,
            name: magicItem.id,
            iconName: ""
        )
    }
}
