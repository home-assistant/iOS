import Shared
import SwiftUI

struct WatchAssistView: View {
    @StateObject private var viewModel: WatchAssistViewModel

    /// Used when there are multiple server
    @State private var showSettings = false
    /// Used when there are just one server for quicker access to pipeline selection
    @State private var showPipelinesPicker = false

    init(
        viewModel: WatchAssistViewModel
    ) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            chatList
            stateView
        }
        .animation(.easeInOut, value: viewModel.state)
        .modify {
            if #available(watchOS 10, *) {
                $0.toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        pipelineSelector
                    }
                }
            } else {
                $0.toolbar {
                    pipelineSelector
                }
            }
        }
        .onAppear {
            if viewModel.assistService.pipelines.isEmpty {
                viewModel.assistService.fetchPipelines { _ in
                    viewModel.assist()
                }
            } else {
                viewModel.assist()
            }
        }
        .onChange(of: viewModel.state) { newValue in
            // TODO: On watchOS 10 this can be replaced by '.sensoryFeedback' modifier
            let currentDevice = WKInterfaceDevice.current()
            switch newValue {
            case .recording:
                currentDevice.play(.start)
            case .waitingForPipelineResponse:
                currentDevice.play(.start)
            default:
                break
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            WatchAssistSettings()
                .environmentObject(viewModel.assistService)
        }
    }

    @ViewBuilder
    private var stateView: some View {
        micRecording
            .opacity(viewModel.state == .recording ? 1 : 0)
        ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(.init(floatLiteral: 2))
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modify {
                if #available(watchOS 10, *) {
                    $0.background(.regularMaterial)
                } else {
                    $0.background(.black.opacity(0.5))
                }
            }
            .opacity(viewModel.state == .loading ? 1 : 0)
    }

    @ViewBuilder
    private var pipelineSelector: some View {
        if viewModel.assistService.pipelines.count > 1 || viewModel.assistService.servers.count > 1,
           let firstPipelineName = viewModel.assistService.pipelines
           .first(where: { $0.id == viewModel.assistService.preferredPipeline })?.name,
           let firstPipelineNameChar = firstPipelineName.first {
            Button {
                if viewModel.assistService.servers.count > 1 {
                    showSettings = true
                } else {
                    showPipelinesPicker = true
                }
            } label: {
                HStack {
                    if #available(watchOS 10, *) {
                        Text(String(firstPipelineNameChar))
                    } else {
                        // When watchS below 10, this item has more space available
                        Text(String(firstPipelineName))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal)
            }
            .confirmationDialog(L10n.Assist.PipelinesPicker.title, isPresented: $showPipelinesPicker) {
                ForEach(viewModel.assistService.pipelines, id: \.id) { pipeline in
                    Button {
                        viewModel.assistService.preferredPipeline = pipeline.id
                    } label: {
                        Text(pipeline.name)
                    }
                }
            }
        }
    }

    private var micButton: some View {
        Button {
            viewModel.assist()
        } label: {
            micImage
        }
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .padding(.horizontal, Spaces.two)
        .padding(.top, Spaces.one)
        .padding(.bottom, -Spaces.two)
        .modify {
            if #available(watchOS 10, *) {
                $0.background(.thinMaterial)
            } else {
                $0.background(.black.opacity(0.5))
            }
        }
    }

    private var micImage: some View {
        Image(uiImage: MaterialDesignIcons.microphoneIcon.image(
            ofSize: .init(width: 24, height: 24),
            color: .white
        ))
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.asset(Asset.Colors.haPrimary))
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }

    @ViewBuilder
    private var micRecording: some View {
        Button(action: {
            viewModel.assist()
        }, label: {
            if #available(watchOS 10.0, *) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .symbolEffect(
                        .variableColor.cumulative.dimInactiveLayers.nonReversing,
                        options: .repeating,
                        value: viewModel.state
                    )
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.asset(Asset.Colors.haPrimary))
                    .frame(maxHeight: .infinity)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 50))
            }
        })
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modify {
            if #available(watchOS 10, *) {
                $0.background(.regularMaterial)
            } else {
                $0.background(.black.opacity(0.5))
            }
        }
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.chatItems, id: \.id) { item in
                    makeChatBubble(item: item)
                        .listRowBackground(Color.clear)
                        .id(item.id)
                }
                if viewModel.chatItems.isEmpty {
                    emptyState
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.easeInOut, value: viewModel.chatItems)
            .onChange(of: viewModel.chatItems) { _ in
                if let lastItem = viewModel.chatItems.last {
                    proxy.scrollTo(lastItem.id, anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            micButton
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Image(uiImage: Asset.SharedAssets.casitaDark.image)
                .resizable()
                .frame(
                    width: 70,
                    height: 70,
                    alignment: .center
                )
                .aspectRatio(contentMode: .fit)
                .opacity(0.5)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }

    private func makeChatBubble(item: AssistChatItem) -> some View {
        Text(item.content)
            .padding(8)
            .padding(.horizontal, 8)
            .background(backgroundForChatItemType(item.itemType))
            .roundedCorner(10, corners: roundedCornersForChatItemType(item.itemType))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: alignmentForChatItemType(item.itemType))
    }

    private func backgroundForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input:
            .asset(Asset.Colors.haPrimary)
        case .output:
            .gray
        case .error:
            .red
        case .info:
            .gray.opacity(0.5)
        }
    }

    private func alignmentForChatItemType(_ itemType: AssistChatItem.ItemType) -> Alignment {
        switch itemType {
        case .input:
            .trailing
        case .output:
            .leading
        case .error, .info:
            .center
        }
    }

    private func roundedCornersForChatItemType(_ itemType: AssistChatItem.ItemType) -> UIRectCorner {
        switch itemType {
        case .input:
            [.topLeft, .topRight, .bottomLeft]
        case .output:
            [.topLeft, .topRight, .bottomRight]
        case .error, .info:
            [.allCorners]
        }
    }
}

#Preview {
    if #available(watchOS 10, *) {
        NavigationStack {
            WatchAssistView.build()
        }
    } else {
        NavigationView {
            WatchAssistView.build()
        }
    }
}
