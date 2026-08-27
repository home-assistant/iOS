import GRDB
import SFSafeSymbols
import Shared
import SwiftUI

struct AssistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AssistViewModel
    @StateObject private var assistSession = AssistSession.shared
    @FocusState private var isFirstResponder: Bool
    @State private var showSettings = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let iconSize: CGSize = .init(width: 28, height: 28)
    private let iconColor: UIColor = .gray
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    private let showCloseButton: Bool

    init(viewModel: AssistViewModel, showCloseButton: Bool = true) {
        self._viewModel = .init(wrappedValue: viewModel)
        self.showCloseButton = showCloseButton
    }

    var body: some View {
        classicUI
            .onAppear {
                assistSession.inProgress = true
                viewModel.initialRoutine()
                viewModel.subscribeForConfigChanges()
            }
            .onChange(of: viewModel.focusOnInput) { newValue in
                if newValue {
                    isFirstResponder = true
                }
            }
            .onDisappear {
                assistSession.inProgress = false
                viewModel.onDisappear()
            }
            .alert(isPresented: $viewModel.showError) {
                .init(
                    title: Text(verbatim: L10n.errorLabel),
                    message: Text(viewModel.errorMessage),
                    dismissButton: .default(Text(verbatim: L10n.okLabel))
                )
            }
    }

    // MARK: - Configuration Persistence

    private var classicUI: some View {
        NavigationView {
            VStack(spacing: .zero) {
                if !Current.isCatalyst {
                    pipelinesPicker
                }
                chatList
            }
            .navigationTitle("Assist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showCloseButton {
                        closeButton
                    }
                }

                #if !targetEnvironment(macCatalyst)
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        settingsButton
                    }
                }
                #endif

                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .topBarTrailing) {
                    macPicker
                }
                #endif
            }
            .sheet(isPresented: $showSettings) {
                if #available(iOS 26.0, *) {
                    AssistSettingsView()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemSymbol: .xmark)
        }
        .buttonStyle(.plain)
        .tint(Color(uiColor: .label))
        .keyboardShortcut(.cancelAction)
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemSymbol: .gearshape)
        }
        .buttonStyle(.plain)
        .tint(Color(uiColor: .label))
    }

    private var pipelinesPicker: some View {
        Picker(L10n.Assist.PipelinesPicker.title, selection: $viewModel.preferredPipelineId) {
            ForEach(viewModel.pipelines, id: \.id) { pipeline in
                Text(pipeline.name)
                    .font(.footnote)
                    .tag(pipeline.id)
            }
        }
        .pickerStyle(.menu)
        .tint(.gray)
        .modify { view in
            if #available(iOS 26.0, *) {
                view.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                view.background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.bottom)
    }

    private var macPicker: some View {
        Menu {
            Picker(L10n.Assist.PipelinesPicker.title, selection: $viewModel.preferredPipelineId) {
                ForEach(viewModel.pipelines, id: \.id) { pipeline in
                    Text(pipeline.name)
                        .tag(pipeline.id)
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spaces.half) {
                Text(selectedPipelineName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemSymbol: .chevronUpChevronDown)
            }
        }
        .frame(maxWidth: 200, alignment: .trailing)
    }

    private var selectedPipelineName: String {
        viewModel.pipelines.first { $0.id == viewModel.preferredPipelineId }?.name
            ?? L10n.Assist.PipelinesPicker.title
    }

    private func makeChatBubble(item: AssistChatItem) -> some View {
        VStack {
            if item.itemType == .typing {
                AssistTypingIndicator()
                    .padding(.vertical, DesignSystem.Spaces.half)
            } else {
                Text(item.markdown)
            }
        }
        .padding(DesignSystem.Spaces.one)
        .padding(.horizontal, DesignSystem.Spaces.one)
        .background(backgroundForChatItemType(item.itemType))
        .roundedCorner(DesignSystem.CornerRadius.oneAndMicro, corners: roundedCornersForChatItemType(item.itemType))
        .overlay {
            if item.itemType == .pending {
                RoundedCorner(
                    radius: DesignSystem.CornerRadius.oneAndMicro,
                    corners: roundedCornersForChatItemType(item.itemType)
                )
                .stroke(Color.haPrimary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }
        }
        .foregroundColor(foregroundForChatItemType(item.itemType))
        .tint(tintForChatItemType(item.itemType))
        .frame(maxWidth: .infinity, alignment: alignmentForChatItemType(item.itemType))
        .textSelection(.enabled)
    }

    private var chatList: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack {
                    ForEach(viewModel.chatItems, id: \.id) { item in
                        makeChatBubble(item: item)
                            .id(item.id)
                            .padding(.bottom)
                    }
                }
                .padding()
                .onChange(of: viewModel.chatItems) { _ in
                    proxy.scrollTo(viewModel.chatItems.last?.id)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    /// Position is where it will be placed related to the list
    private func linearGradientDivider(position: UnitPoint) -> some View {
        VStack {}
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .background(LinearGradient(colors: [
                Color(uiColor: .systemBackground),
                .clear,
            ], startPoint: position, endPoint: position == .top ? .bottom : .top))
    }

    private var bottomBar: some View {
        ZStack {
            inputTextView
            recordingView
        }
        .frame(maxHeight: 80)
    }

    private var inputTextView: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            TextField("", text: $viewModel.inputText)
                .textFieldStyle(.plain)
                .focused($isFirstResponder)
                .onSubmit {
                    viewModel.assistWithText()
                    if Current.isCatalyst {
                        isFirstResponder = true
                    }
                }
            if viewModel.inputText.isEmpty {
                assistMicButton
            } else {
                assistSendTextButton
            }
        }
        .padding(.vertical, DesignSystem.Spaces.one)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .modify { view in
            if #available(iOS 26.0, *) {
                view.glassEffect(.regular, in: .capsule)
            } else {
                view
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.tileBorder, lineWidth: 1))
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.vertical)
        .padding(.bottom, horizontalSizeClass == .regular ? DesignSystem.Spaces.two : DesignSystem.Spaces.half)
        .opacity(viewModel.isRecording ? 0 : 1)
        .allowsHitTesting(!viewModel.isRecording)
        .animation(.smooth, value: viewModel.isRecording)
    }

    private var recordingView: some View {
        ZStack {
            Button {
                feedbackGenerator.notificationOccurred(.warning)
                viewModel.assistWithAudio()
            } label: {
                AssistVoiceOrbView(level: viewModel.audioLevel)
            }
            .buttonStyle(.plain)

            HStack {
                Spacer()
                keyboardButton
            }
            .padding(.trailing, DesignSystem.Spaces.two)
        }
        .opacity(viewModel.isRecording ? 1 : 0)
        .allowsHitTesting(viewModel.isRecording)
        .animation(.smooth, value: viewModel.isRecording)
    }

    private var keyboardButton: some View {
        Button {
            feedbackGenerator.notificationOccurred(.success)
            viewModel.stopStreaming()
            isFirstResponder = true
        } label: {
            Image(systemSymbol: .keyboard)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .modify { view in
            if #available(iOS 26.0, *) {
                view.glassEffect(.regular.interactive(), in: .circle)
            } else {
                view
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.tileBorder, lineWidth: 1))
            }
        }
    }

    private var assistSendTextButton: some View {
        Button(action: {
            viewModel.assistWithText()
        }, label: {
            sendIcon
        })
        .buttonStyle(.plain)
        .font(.system(size: 32))
        .tint(Color.haPrimary)
        .keyboardShortcut(.defaultAction)
    }

    @ViewBuilder
    private var assistMicButton: some View {
        Button(action: {
            assistMicButtonAction()
        }, label: {
            Image(uiImage: MaterialDesignIcons.microphoneIcon.image(ofSize: iconSize, color: iconColor))
        })
        .buttonStyle(.plain)
        .keyboardShortcut(.init("a"))
        .font(.system(size: iconSize.width))
    }

    private func assistMicButtonAction() {
        feedbackGenerator.notificationOccurred(.success)
        isFirstResponder = false

        viewModel.assistWithAudio()
    }

    private var sendIcon: some View {
        Image(uiImage: MaterialDesignIcons.sendIcon.image(ofSize: iconSize, color: iconColor))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.haPrimary)
    }

    private func backgroundForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input:
            .haPrimary
        case .output, .typing:
            .secondaryBackground
        case .error:
            .red
        case .info:
            .gray.opacity(0.5)
        case .pending:
            .clear
        }
    }

    private func foregroundForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input, .error:
            .white
        case .info:
            .secondary
        default:
            .primary
        }
    }

    private func tintForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input, .error:
            .white
        default:
            .haPrimary
        }
    }

    private func alignmentForChatItemType(_ itemType: AssistChatItem.ItemType) -> Alignment {
        switch itemType {
        case .input, .pending:
            .trailing
        case .output, .typing:
            .leading
        case .error, .info:
            .center
        }
    }

    private func roundedCornersForChatItemType(_ itemType: AssistChatItem.ItemType) -> UIRectCorner {
        switch itemType {
        case .input, .pending:
            [.topLeft, .topRight, .bottomLeft]
        case .output, .typing:
            [.topLeft, .topRight, .bottomRight]
        case .error, .info:
            [.allCorners]
        }
    }
}

#Preview("Text mode") {
    AssistView.build(server: ServerFixture.standard)
}

#Preview("Recording") {
    let viewModel = AssistViewModel(
        server: ServerFixture.standard,
        audioRecorder: AudioRecorder(),
        audioPlayer: AudioPlayer(),
        assistService: AssistService(server: ServerFixture.standard),
        autoStartRecording: false
    )
    viewModel.isRecording = true
    viewModel.audioLevel = 0.6
    return AssistView(viewModel: viewModel)
}
