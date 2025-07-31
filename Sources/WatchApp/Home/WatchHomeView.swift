import Shared
import SwiftUI

struct WatchHomeView: View {
    @StateObject private var viewModel = WatchHomeViewModel()
    @State private var showAssist = false

    var body: some View {
        navigation
            .onReceive(NotificationCenter.default.publisher(for: AssistDefaultComplication.launchNotification)) { _ in
                showAssist = true
            }
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
            watchOS10Content
        } else {
            olderWatchOSContent
        }
    }

    @available(watchOS 10, *)
    private var watchOS10Content: some View {
        NavigationStack {
            content
                .persistentSystemOverlays(.hidden)
                .toolbar {
                    reloadToolbarButton
                    if viewModel.showAssist {
                        assistToolbarButton
                    }
                    if viewModel.isLoading {
                        toolbarLoadingState
                    }
                }
        }
    }

    private var olderWatchOSContent: some View {
        NavigationView {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            inlineLoader
            listContent
            appVersion
        }
        .id(viewModel.refreshListID)
        .navigationTitle("")
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.watchConfig.items.isEmpty {
            Text(verbatim: L10n.Watch.Labels.noConfig)
                .font(.footnote)
        } else {
            mainContent
        }
    }

    @ViewBuilder
    private var inlineReloadButton: some View {
        if viewModel.watchConfig.items.isEmpty || viewModel.showError {
            reloadButton
        }
    }

    @ViewBuilder
    private var inlineLoader: some View {
        // Loader is displayed in list when watchOS 10 is not available
        if viewModel.isLoading, #unavailable(watchOS 10.0) {
            loadingState
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var inlineError: some View {
        if viewModel.showError {
            Text(viewModel.errorMessage)
                .font(.footnote)
                .listRowBackground(
                    Color.red.opacity(0.5)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
                )
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        assistButtonForOlderDevices
        ForEach(viewModel.watchConfig.items, id: \.serverUniqueId) { item in
            WatchMagicViewRow(
                item: item,
                itemInfo: viewModel.info(for: item)
            )
        }
        reloadButton
    }

    @available(watchOS 10, *)
    private var reloadToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            navReloadButton
        }
    }

    @available(watchOS 10, *)
    private var assistToolbarButton: some ToolbarContent {
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

    private var assistButton: some View {
        Button(action: {
            showAssist = true
        }, label: {
            let color: UIColor = {
                if #available(watchOS 26.0, *) {
                    return .white
                } else {
                    return UIColor(Color.haPrimary)
                }
            }()
            Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                ofSize: .init(width: 24, height: 24),
                color: color
            ))
        })
        .modify { view in
            if #available(watchOS 26.0, *) {
                view
                    .tint(.haPrimary)
            } else {
                view
            }
        }
    }

    @available(watchOS 10, *)
    private var navReloadButton: some View {
        Button {
            viewModel.requestConfig()
        } label: {
            Image(systemSymbol: .arrowCirclepath)
        }
    }

    @available(watchOS 10, *)
    private var toolbarLoadingState: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            loadingState
                .modify { view in
                    if #available(watchOS 26.0, *) {
                        view
                            .glassEffect(in: .circle)
                    } else {
                        view
                            .padding()
                            .background(.black)
                    }
                }
        }
    }

    private var loadingState: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }

    private var appVersion: some View {
        Text(verbatim: AppConstants.version)
            .listRowBackground(Color.clear)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var reloadButton: some View {
        // When watchOS 10 is available, reload is on toolbar
        if #unavailable(watchOS 10.0) {
            Button {
                viewModel.requestConfig()
            } label: {
                Group {
                    if #available(watchOS 10.0, *) {
                        Label(L10n.reloadLabel, systemSymbol: .arrowCirclepath)
                    } else {
                        Label(L10n.reloadLabel, systemSymbol: .arrowTriangle2CirclepathCircle)
                    }
                }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.footnote)
            }
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var assistButtonForOlderDevices: some View {
        if #unavailable(watchOS 10),
           viewModel.watchConfig.assist.showAssist,
           !viewModel.watchConfig.assist.serverId.isEmpty,
           !viewModel.watchConfig.assist.pipelineId.isEmpty {
            assistButton
        }
    }
}
