import Shared
import SwiftUI

struct WatchAssistView: View {
    @StateObject private var viewModel: WatchAssistViewModel
    @EnvironmentObject private var assistService: WatchAssistService

    /// Used when there are multiple server
    @State private var showSettings = false
    /// Used when there are just one server for quicker access to pipeline selection
    @State private var showPipelinesPicker = false

    private let progressViewId = "progressViewId"

    init(
        viewModel: WatchAssistViewModel
    ) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            micButton
            chatList
            stateView
            inlineLoading
        }
        .animation(.easeInOut, value: viewModel.state)
        /* Double tap for watchOS 11
         .handGestureShortcut(.primaryAction)
          */
        .onTapGesture {
            viewModel.assist(assistService)
        }
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
            initialRoutine()
        }
        .onDisappear {
            viewModel.stopRecording()
        }
        .onChange(of: viewModel.state) { newValue in
            // TODO: On watchOS 10 this can be replaced by '.sensoryFeedback' modifier
            let currentDevice = WKInterfaceDevice.current()
            switch newValue {
            case .recording, .waitingForPipelineResponse:
                currentDevice.play(.start)
            default:
                break
            }
        }
        .onChange(of: showSettings) { newValue in
            if newValue {
                viewModel.stopRecording()
            }
        }
        .onChange(of: showPipelinesPicker) { newValue in
            if newValue {
                viewModel.stopRecording()
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            WatchAssistSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: AssistDefaultComplication.launchNotification)) { _ in
            initialRoutine()
        }
    }

    private func initialRoutine() {
        viewModel.state = .loading
        if assistService.pipelines.isEmpty {
            assistService.fetchPipelines { _ in
                viewModel.assist(assistService)
            }
        } else {
            viewModel.assist(assistService)
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
        if assistService.pipelines.count > 1 || assistService.servers.count > 1,
           let firstPipelineName = assistService.pipelines
           .first(where: { $0.id == assistService.preferredPipeline })?.name,
           let firstPipelineNameChar = firstPipelineName.first {
            Button {
                if assistService.servers.count > 1 {
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
                        Text(firstPipelineName)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal)
            }
            .confirmationDialog(L10n.Assist.PipelinesPicker.title, isPresented: $showPipelinesPicker) {
                ForEach(assistService.pipelines, id: \.id) { pipeline in
                    Button {
                        assistService.preferredPipeline = pipeline.id
                    } label: {
                        Text(pipeline.name)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var micButton: some View {
        if ![.loading, .recording].contains(viewModel.state), !viewModel.showChatLoader {
            HStack {
                Text(L10n.Assist.Watch.MicButton.title)
                Image(systemName: "mic.fill")
            }
            .font(.system(size: 11))
            .foregroundStyle(.gray)
            .offset(y: 22)
        }
    }

    @ViewBuilder
    private var inlineLoading: some View {
        if ![.loading, .recording].contains(viewModel.state) {
            if viewModel.showChatLoader {
                micButtonProgressView
            }
        }
    }

    private var micButtonProgressView: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(.init(floatLiteral: 1.5))
            .frame(maxWidth: .infinity, alignment: .center)
            .progressViewStyle(.linear)
            .frame(height: 40)
            .padding(Spaces.half)
            .modify {
                if #available(watchOS 10, *) {
                    $0.background(.regularMaterial)
                } else {
                    $0.background(.black.opacity(0.3))
                }
            }
            .clipShape(Circle())
    }

    @ViewBuilder
    private var micRecording: some View {
        Button(action: {
            viewModel.assist(assistService)
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
            ScrollView {
                // Using LazyVStack instead of List to avoid List minimum row height
                LazyVStack(spacing: Spaces.one) {
                    ForEach(viewModel.chatItems, id: \.id) { item in
                        ChatBubbleView(item: item)
                    }
                    if viewModel.chatItems.isEmpty {
                        emptyState
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal)
                .animation(.easeInOut, value: viewModel.chatItems)
                .onChange(of: viewModel.chatItems) { _ in
                    if let lastItem = viewModel.chatItems.last {
                        proxy.scrollTo(lastItem.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
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
}
