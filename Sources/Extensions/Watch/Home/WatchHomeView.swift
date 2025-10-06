import Shared
import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = WatchHomeViewModel()
    @State private var showAssist = false


    var body: some View {
        navigation
            ._statusBarHidden(true)
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
                Task {
                    await viewModel.fetchNetworkInfo()
                    viewModel.initialRoutine()
                }
            }
            .onChange(of: scenePhase) { newValue in
                switch newValue {
                case .active:
                    Task {
                        await viewModel.fetchNetworkInfo()
                    }
                case .background:
                    break
                case .inactive:
                    break
                @unknown default:
                    break
                }
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
            listHeader
            listContent
            footer
        }
        // Removing the safe area so our fake navigation bar buttons (header) can be place correctly
        .ignoresSafeArea([.all], edges: .top)
        .id(viewModel.refreshListID)
        .navigationTitle("")
        .modify { view in
            if #available(watchOS 11.0, *) {
                view.toolbarVisibility(.hidden, for: .navigationBar)
            } else {
                view
            }
        }
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
    private var listHeader: some View {
        HStack {
            navReloadButton
            Spacer()
            if viewModel.isLoading {
                toolbarLoadingState
            }
            if viewModel.showAssist {
                Spacer()
                assistHeaderButton
            } else {
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
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
        ForEach(viewModel.watchConfig.items, id: \.serverUniqueId) { item in
            WatchMagicViewRow(
                item: item,
                itemInfo: viewModel.info(for: item)
            )
        }
    }

    private var assistHeaderButton: some View {
        assistButton
            .modify { view in
                if #available(watchOS 11, *) {
                    view.handGestureShortcut(.primaryAction)
                } else {
                    view
                }
            }
            .circularGlassOrLegacyBackground()
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
        .buttonStyle(.plain)
        .modify { view in
            if #available(watchOS 26.0, *) {
                view
                    .tint(.haPrimary)
            } else {
                view
            }
        }
    }

    private var navReloadButton: some View {
        Button {
            viewModel.requestConfig()
        } label: {
            Image(systemSymbol: .arrowCounterclockwise)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground()
    }

    private var toolbarLoadingState: some View {
        loadingState
            .circularGlassOrLegacyBackground()
    }

    private var loadingState: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }

    private var footer: some View {
        VStack(spacing: .zero) {
            appVersion
            ssidLabel
        }
        .listRowBackground(Color.clear)
    }

    private var appVersion: some View {
        Text(verbatim: AppConstants.version)
            .listRowBackground(Color.clear)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var ssidLabel: some View {
        if !viewModel.currentSSID.isEmpty {
            Label {
                Text(verbatim: viewModel.currentSSID)
                    .minimumScaleFactor(0.5)
            } icon: {
                Image(systemSymbol: .wifi)
            }
            .font(DesignSystem.Font.caption2)
            .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}
