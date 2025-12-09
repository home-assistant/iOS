import Shared
import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = WatchHomeViewModel()
    @State private var showAssist = false

    var body: some View {
        content
            ._statusBarHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: AssistDefaultComplication.launchNotification)) { _ in
                showAssist = true
            }
            .fullScreenCover(isPresented: $showAssist, content: {
                if let serverId = viewModel.watchConfig.assist.serverId,
                   let pipelineId = viewModel.watchConfig.assist.pipelineId {
                    WatchAssistView.build(
                        serverId: serverId,
                        pipelineId: pipelineId
                    )
                } else {
                    fatalError("Assist launched without serverId or pipelineId")
                }
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
            } else if #available(watchOS 9.0, *) {
                view
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                view
                    .navigationBarHidden(true)
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
            toolbarLoadingState
            assistHeaderButton
        }
        .listRowBackground(Color.clear)
        .padding(.top, DesignSystem.Spaces.one)
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

    @ViewBuilder
    private var assistHeaderButton: some View {
        if viewModel.showAssist {
            assistButton
                .modify { view in
                    if #available(watchOS 11, *) {
                        view.handGestureShortcut(.primaryAction)
                    } else {
                        view
                    }
                }
                .circularGlassOrLegacyBackground(tint: .haPrimary)
        } else {
            // Reserve space to keep the loader centered
            Rectangle()
                .foregroundStyle(Color.clear)
                .frame(width: 44, height: 44)
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

    @ViewBuilder
    private var toolbarLoadingState: some View {
        HStack {
            if viewModel.isLoading {
                loadingState
                    .circularGlassOrLegacyBackground()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var loadingState: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }

    private var footer: some View {
        VStack(spacing: .zero) {
            appVersion
            complicationCount
            ssidLabel
        }
        .listRowBackground(Color.clear)
    }

    private var appVersion: some View {
        VStack(alignment: .center, spacing: .zero) {
            Text(verbatim: AppConstants.version)
            Text(verbatim: "(\(AppConstants.build))")
                .font(DesignSystem.Font.caption3)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
        .foregroundStyle(.secondary)
    }
    
    private var complicationCount: some View {
        Text(verbatim: "Complications: \(viewModel.complicationCount)")
            .font(DesignSystem.Font.caption3)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
            .foregroundStyle(.secondary)
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
